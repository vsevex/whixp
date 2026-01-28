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
  Session(this.features, this.transport);

  final Transport transport;

  JabberID? bindJID;
  SMState? state;
  bool enabledOut = false;
  final StreamFeatures features;

  Future<bool> bind() async {
    final resource = transport.boundJID?.resource;
    Bind bind = const Bind();
    if (resource?.isNotEmpty ?? false) bind = Bind(resource: resource);

    final iq = IQ(generateID: true);
    iq.type = iqTypeSet;
    iq.payload = bind;

    final result = await iq.send(transport);
    if (result.payload != null && result.error == null) {
      bindJID = JabberID((result.payload! as Bind).jid);
      if (!features.doesStreamManagement) {
        transport.emit('startSession');
      }
      return true;
    } else {
      Log.instance.warning('IQ bind result is missing');
      return false;
    }
  }

  Future<bool> resume(
    String? jidKey, {
    required void Function() onResumeDone,
    required Future<bool> Function() onResumeFailed,
  }) async {
    if (jidKey?.isEmpty ?? true) return false;
    if (!features.doesStreamManagement) return false;
    transport.callbacksBeforeStanzaSend
        .add((stanza) => _handleOutgoing(jidKey, stanza as Stanza));
    state = await StreamManagement.getSMStateFromLocal(
      transport.databaseController,
      jidKey,
    );
    // Backward compatibility: older versions stored state keyed by full JID.
    if (state == null) {
      final full = transport.boundJID?.full;
      if (full?.isNotEmpty ?? false) {
        state = await StreamManagement.getSMStateFromLocal(
          transport.databaseController,
          full,
        );
      }
    }
    if (state == null) {
      Log.instance.info(
          'No previous stream state found, will enable stream management');
      return await onResumeFailed.call();
    }

    final resume = SMResume(h: state?.handled, previd: state?.id);

    Log.instance.info('Attempting to resume stream with previd: ${state?.id}');
    final result = await transport.sendAwait<SMResumed, SMFailed>(
      'SM Resume Handler',
      resume,
      'sm:resumed',
      failurePacket: 'sm:failed',
      timeout: 2,
    );

    if (result != null) {
      if (result is SMFailed) {
        Log.instance.warning('SM resume failed: ${result.cause?.content}');
        // Fall back to enabling stream management
        return await onResumeFailed.call();
      } else {
        onResumeDone.call();
        transport.emit('startSession');
        return true;
      }
    } else {
      // Timeout - fall back to enabling stream management
      return await onResumeFailed.call();
    }
  }

  Future<bool> enableStreamManagement(
    Future<void> Function(Packet packet) onEnabled,
  ) async {
    if (!features.doesStreamManagement) return false;

    // Ensure bind is completed before enabling stream management
    if (bindJID == null) {
      Log.instance
          .info('Binding resource before enabling stream management...');
      await bind.call();
      if (bindJID == null) {
        Log.instance.warning(
          'Failed to bind resource, cannot enable stream management',
        );
        return false;
      }
    }

    Log.instance.info('Enabling stream management...');
    const enable = SMEnable(resume: true);
    Log.instance
        .info('Sending stream management enable request: ${enable.toXML()}');

    try {
      final result = await transport.sendAwait<SMEnabled, SMFailed>(
        'SM Enable Handler',
        enable,
        'sm:enabled',
        failurePacket: 'sm:failed',
        timeout: 5, // Increase timeout to 5 seconds to match error message
      );

      if (result != null) {
        if (result is SMFailed) {
          Log.instance.warning(
              'Stream management enable failed: ${result.cause?.content}');
          return false;
        }
        Log.instance.info('Stream management enabled successfully');
        await onEnabled.call(result);
        state = state?.copyWith(handled: 0);

        transport.emit('startSession');
        return true;
      } else {
        Log.instance.error(
          'Stream management enable timed out - server did not respond',
        );
        // Even on timeout, emit startSession to allow the connection to continue
        // The server may have enabled SM but not responded, or SM may not be required
        transport.emit('startSession');
        return false;
      }
    } catch (e) {
      Log.instance.error(
        'Exception while enabling stream management: $e',
      );
      // Emit startSession even on error to allow connection to continue
      transport.emit('startSession');
      return false;
    }
  }

  void sendAnswer() {
    final answer = SMAnswer(h: state?.handled ?? 0);
    return transport.send(answer);
  }

  void request() {
    Log.instance.warning('Requesting Ack');
    const request = SMRequest();
    return transport.send(request);
  }

  Future<void> handleAnswer(Packet packet, String? full) async {
    if (packet is! SMAnswer) return;
    if (packet.h == state?.lastAck) return;
    if (full?.isEmpty ?? true) return;

    int numAcked = ((packet.h ?? 0) - (state?.lastAck ?? 0)) % _seq;
    final unackeds = StreamManagement.getUnackeds(transport.databaseController);
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
      final unacked =
          StreamManagement.popFromUnackeds(transport.databaseController);
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
          return transport.emit<String>('ackedRaw', data: raw);
        }

        transport.emit<Stanza>('ackedStanza', data: stanza);
      } catch (_) {
        transport.emit<String>('ackedRaw', data: unacked);
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
      // Never await database writes in the send pipeline.
      // In CLI apps a blocking stdin read can pause the event loop and make
      // these awaited futures appear "stuck" (especially with background DB
      // executors). Persist asynchronously and log on failure.
      final unackedFuture = StreamManagement.saveUnackedToLocal(
        transport.databaseController,
        sequence,
        stanza,
      );
      if (unackedFuture != null) {
        unackedFuture.catchError((e) {
          Log.instance
              .error('Failed to persist unacked stanza (seq=$sequence): $e');
        });
      }
      saveSMState(fullJID, state).catchError((e) {
        Log.instance.error('Failed to persist SM state: $e');
      });
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

  Future<void> saveSMState(String? jidKey, SMState? state) async {
    if ((jidKey?.isEmpty ?? true) || state == null) return;
    this.state = state;
    await StreamManagement.saveSMStateToLocal(
      transport.databaseController,
      jidKey!,
      state,
    );
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
