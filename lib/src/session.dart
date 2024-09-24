import 'dart:math' as math;

import 'package:whixp/src/_static.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/features.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/message.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/stanza/presence.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/transport.dart';

final int _seq = math.pow(2, 32) as int;

class Session {
  Session(this.features);

  JabberID? bindJID;
  SMState? state;
  bool enabledOut = false;
  final StreamFeatures features;

  Future<bool> bind() async {
    final resource = Transport.instance().boundJID?.resource;
    Bind bind = const Bind();
    if (resource?.isNotEmpty ?? false) bind = Bind(resource: resource);

    final iq = IQ(generateID: true);
    iq.type = iqTypeSet;
    iq.payload = bind;

    final result = await iq.send();
    if (result.payload != null && result.error == null) {
      bindJID = JabberID((result.payload! as Bind).jid);
      if (!features.doesStreamManagement) {
        Transport.instance().emit('startSession');
      }
    } else {
      Log.instance.warning('IQ bind result is missing');
    }
    return false;
  }

  Future<bool> resume(
    String? fullJID, {
    required void Function() onResumeDone,
    required Future<bool> Function() onResumeFailed,
  }) async {
    if (fullJID?.isEmpty ?? true) return false;
    if (!features.doesStreamManagement) return false;
    Transport.instance()
        .callbacksBeforeStanzaSend
        .add((stanza) async => _handleOutgoing(fullJID, stanza as Stanza));
    state = await StreamManagement.getSMStateFromLocal(fullJID);
    if (state == null) return onResumeFailed.call();

    final resume = SMResume(h: state?.handled, previd: state?.id);

    final result = await Transport.instance().sendAwait<SMResumed, SMFailed>(
      'SM Resume Handler',
      resume,
      'sm:resumed',
      failurePacket: 'sm:failed',
    );

    if (result != null) {
      if (result is SMFailed) {
        Log.instance.warning('SM failed: ${result.cause?.content}');
      } else {
        onResumeDone.call();
        Transport.instance().emit('startSession');
      }
      return false;
    } else {
      return await onResumeFailed.call();
    }
  }

  Future<bool> enableStreamManagement(
    Future<void> Function(Packet packet) onEnabled,
  ) async {
    if (!features.doesStreamManagement) return false;
    const enable = SMEnable(resume: true);
    if (bindJID == null) await bind.call();
    final result = await Transport.instance().sendAwait<SMEnabled, SMFailed>(
      'SM Enable Handler',
      enable,
      'sm:enabled',
      failurePacket: 'sm:failed',
    );

    if (result != null) {
      await onEnabled.call(result);
      state = state?.copyWith(handled: 0);

      Transport.instance().emit('startSession');
    }

    return false;
  }

  void sendAnswer() {
    final answer = SMAnswer(h: state?.handled ?? 0);
    return Transport.instance().send(answer);
  }

  void request() {
    Log.instance.warning('Requesting Ack');
    const request = SMRequest();
    return Transport.instance().send(request);
  }

  Future<void> handleAnswer(Packet packet, String? full) async {
    if (packet is! SMAnswer) return;
    if (packet.h == state?.lastAck) return;
    if (full?.isEmpty ?? true) return;

    int numAcked = ((packet.h ?? 0) - (state?.lastAck ?? 0)) % _seq;
    final unackeds = StreamManagement.unackeds;
    if (unackeds == null) {
      state = state?.copyWith(lastAck: packet.h);
      return saveSMState(full, state);
    }

    Log.instance.warning(
      'Acked: ${packet.h}, Last acked: ${state?.lastAck}, Unacked: ${unackeds.length}, Num acked: $numAcked, Remaining: ${unackeds.length - numAcked}',
    );

    if ((numAcked > unackeds.length) || numAcked < 0) {
      Log.instance.error(
        'Inconsistent sequence numbers from the server, ignoring and replacing ours with them',
      );
      numAcked = unackeds.length;
    }
    int sequence = state?.sequence ?? 1;
    for (int i = 0; i < numAcked; i++) {
      /// Pop and update sequence number
      final unacked = StreamManagement.popFromUnackeds();
      if (unacked?.isEmpty ?? true) return;
      sequence = sequence - 1;

      try {
        final raw = unacked!;
        late Stanza stanza;
        if (raw.startsWith('<message')) {
          stanza = Message.fromString(raw);
        } else if (raw.startsWith('<iq')) {
          stanza = IQ.fromString(raw);
        } else if (raw.startsWith('<presence')) {
          stanza = Presence.fromString(raw);
        } else {
          return Transport.instance().emit<String>('ackedRaw', data: raw);
        }

        Transport.instance().emit<Stanza>('ackedStanza', data: stanza);
      } catch (_) {
        Transport.instance().emit<String>('ackedRaw', data: unacked);
      }
    }

    state = state?.copyWith(lastAck: packet.h, sequence: sequence);
    await saveSMState(full, state);
  }

  Future<Stanza> _handleOutgoing(String? fullJID, Stanza stanza) async {
    if (!enabledOut) return stanza;
    if (fullJID?.isEmpty ?? true) return stanza;

    if (stanza is Message || stanza is IQ || stanza is Presence) {
      final sequence = ((state?.sequence ?? 0) + 1) % _seq;
      state = state?.copyWith(sequence: sequence);
      await StreamManagement.saveUnackedToLocal(sequence, stanza);
      await saveSMState(fullJID, state);
      request();
    }

    return stanza;
  }

  Future<int?> increaseInbound(String? full) async {
    if (full?.isEmpty ?? true) return null;
    final handled = ((state?.handled ?? 0) + 1) % _seq;

    await saveSMState(full, state?.copyWith(handled: handled));

    return handled;
  }

  Future<void> saveSMState(String? fullJID, SMState? state) async {
    if ((fullJID?.isEmpty ?? true) || state == null) return;
    this.state = state;
    await StreamManagement.saveSMStateToLocal(fullJID!, state);
  }

  /// Clears state whenever the session ends.
  void clearSession() {
    bindJID = null;
    state = null;
    enabledOut = false;
  }

  bool get isSessionOpen => bindJID != null;
}

// Holds Stream Management information.
class SMState {
  final String id;
  final int sequence;
  final int handled;
  final int lastAck;

  const SMState(this.id, this.sequence, this.handled, this.lastAck);

  Map<String, dynamic> toJson() => {
        'id': id,
        'sequence': sequence,
        'handled': handled,
        'last_ack': lastAck,
      };

  SMState copyWith({String? id, int? sequence, int? handled, int? lastAck}) =>
      SMState(
        id ?? this.id,
        sequence ?? this.sequence,
        handled ?? this.handled,
        lastAck ?? this.lastAck,
      );

  factory SMState.fromJson(Map<String, dynamic> json) => SMState(
        json['id'] as String,
        json['sequence'] as int,
        json['handled'] as int,
        json['last_ack'] as int,
      );
}
