import 'dart:async';
import 'dart:math' as math;

import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/handler/waiter.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/message.dart';
import 'package:whixp/src/stanza/presence.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/stream/matcher/matcher.dart';
import 'package:whixp/src/transport.dart';

import 'package:xml/xml.dart' as xml;

part 'stanza.dart';

final _maxSeq = math.pow(2, 32).toInt();

/// Stream management implements these features using short XML elements at the
/// root stream level.
///
/// These elements are not "stanzas" in the XMPP sense (i.e., not <iq/>,
/// <message/>, or <presence/> stanzas as defined in RFC 6120) and are not
/// counted or acked in stream management, since they exist for the purpose of
/// managing stanzas themselves.
class StreamManagement extends PluginBase {
  /// Example:
  /// ```xml
  /// <stream:features>
  ///   <bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'/>
  ///   <sm xmlns='urn:xmpp:sm:3'/>
  /// </stream:features>
  /// ```
  StreamManagement({
    this.lastAck = 0,
    this.window = 5,
    this.smID,
    this.handled = 0,
    this.seq = 0,
    this.allowResume = true,
  }) : super('sm', description: 'Stream Management');

  /// The last ack number received from the server.
  int lastAck;

  /// The number of stanzas to wait between sending ack requests to the server.
  ///
  /// Setting this to `1` will send an ack request after every sent stanza.
  /// Defaults to `5`.
  int window;

  /// The stream management ID for the stream. Knowing this value is required
  /// in order to do stream resumption.
  late String? smID;

  /// A counter of handled incoming stanzas, mod 2^32.
  int handled;

  /// A counter of unacked outgoing stanzas, mod 2^32.
  int seq;

  /// Control whether or not the ability to resume the stream will be requested
  /// when enabling stream management. Defaults to `true`.
  final bool allowResume;

  late final Map<int, StanzaBase> _unackedQueue;

  late int _windowCounter;
  late bool enabledIn;
  late bool enabledOut;

  @override
  void pluginInitialize() {
    if (base.isComponent) return;

    _windowCounter = window;

    enabledIn = false;
    enabledOut = false;
    _unackedQueue = <int, StanzaBase>{};

    base
      ..registerFeature('sm', _handleStreamFeature, restart: true, order: 10100)
      ..registerFeature('sm', _handleStreamFeature, restart: true, order: 9000);

    base.transport
      ..registerHandler(
        CallbackHandler(
          'Stream Management Enabled',
          (stanza) => _handleEnabled(stanza as Enabled),
          matcher: XPathMatcher(Enabled().tag),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'Stream Management Resumed',
          _handleResumed,
          matcher: XPathMatcher(Resumed().tag),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'Stream Management Ack',
          _handleAck,
          matcher: XPathMatcher(Ack().tag),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'Stream Management Failed',
          (stanza) => _handleFailed(stanza as Failed),
          matcher: XPathMatcher(Failed().tag),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'Stream Management Request Ack',
          _handleRequestAck,
          matcher: XPathMatcher(RequestAck().tag),
        ),
      );

    base.transport
      ..registerStanza(Enable())
      ..registerStanza(Enabled())
      ..registerStanza(Resume())
      ..registerStanza(Resumed())
      ..registerStanza(Failed())
      ..registerStanza(Ack())
      ..registerStanza(RequestAck())
      ..addFilter(filter: _handleIncoming)
      ..addFilter(mode: FilterMode.out, filter: _handleOutgoing);

    base
      ..addEventHandler<String>('disconnected', _disconnected)
      ..addEventHandler('sessionEnd', _sessionEnd);
  }

  /// Requests an ack from the server.
  void _requestAck() {
    Log.instance.debug('Requesting ack');
    final req = RequestAck();
    base.transport.sendRaw(req.toString());
  }

  /// Resets enabled state until we can resume/reenable.
  void _disconnected(String? event) {
    Log.instance.debug('disconnected, disabling SM');
    base.transport.emit<String>('smDisabled', data: event);
    enabledIn = false;
    enabledOut = false;
  }

  /// Resets stream management state.
  void _sessionEnd(_) {
    Log.instance.debug('session ended, disabling SM');
    base.transport.emit<String>('smDisabled');
    enabledIn = false;
    enabledOut = false;
    smID = null;
    handled = 0;
    seq = 0;
    lastAck = 0;
  }

  /// Enables or resumes stream management.
  ///
  /// If no SM-ID is stored, and resource binding has taken place, stream
  /// management will be enabled.
  ///
  /// If an SM-ID is known, and the server allows resumption, the previous
  /// stream will be resumed.
  Future<bool> _handleStreamFeature(StanzaBase features) async {
    if (base.features.contains('stream_management')) {
      return false;
    }

    if (smID != null && allowResume && !base.features.contains('bind')) {
      final resume = Resume(transport: base.transport);
      resume['h'] = handled;
      resume['previd'] = smID;
      resume.send();
      Log.instance.info('resuming SM');

      final waiter = Waiter(
        'resumedOrFailed',
        matcher: ManyMatcher([
          XPathMatcher(Resumed().tag),
          XPathMatcher(Failed().tag),
        ]),
        transport: base.transport,
      );

      base.transport.registerHandler(waiter);

      final result = await waiter.wait(timeout: 2);

      if (result != null && result.name == 'resumed') {
        return true;
      }
      await base.transport.emit('sessionEnd');
    }
    if (base.features.contains('bind')) {
      final enable = Enable(transport: base.transport);
      enable['resume'] = allowResume;
      enable.send();
      Log.instance.info('enabling SM');

      final waiter = Waiter(
        'enabledOrFailed',
        matcher: ManyMatcher([
          XPathMatcher(Enabled().tag),
          XPathMatcher(Failed().tag),
        ]),
        transport: base.transport,
      );

      base.transport.registerHandler(waiter);
      await waiter.wait(timeout: 2);
    }

    return false;
  }

  StanzaBase _handleIncoming(StanzaBase stanza) {
    if (!enabledIn) {
      return stanza;
    }

    if (stanza is Message || stanza is Presence || stanza is IQ) {
      handled = (handled + 1) % _maxSeq;
    }

    return stanza;
  }

  /// Stores outgoing stanzas in a queue to be acked.
  StanzaBase _handleOutgoing(StanzaBase stanza) {
    if (stanza is Enable || stanza is Resume) {
      enabledOut = true;
      _unackedQueue.clear();
      Log.instance.debug('enabling outoing SM: $stanza');
    }

    if (!enabledOut) {
      return stanza;
    }

    if (stanza is Message || stanza is Presence || stanza is IQ) {
      int? seq;
      seq = (this.seq + 1) % _maxSeq;
      seq = this.seq;

      _unackedQueue[seq] = stanza;
      _windowCounter -= 1;
      if (_windowCounter == 0) {
        _windowCounter = window;
        _requestAck();
      }
    }

    return stanza;
  }

  /// Saves the SM-ID, if provided.
  void _handleEnabled(Enabled enabled) {
    base.features.add('stream_management');
    if (enabled['id'] != null) {
      smID = enabled['id'] as String;
    }
    enabledIn = true;
    handled = 0;
    base.transport.emit<Enabled>('smEnabled', data: enabled);
    base.transport.endSessionOnDisconnect = false;
  }

  void _handleResumed(StanzaBase stanza) {
    base.features.add('stream_management');
    enabledIn = true;
    _handleAck(stanza);
    for (final entry in _unackedQueue.entries) {
      base.transport.send(entry.value, useFilters: false);
    }
    base.transport.emit<StanzaBase>('sessionResumed', data: stanza);
    base.transport.endSessionOnDisconnect = false;
  }

  /// Disabled and resets any features used since stream management was
  /// requested.
  void _handleFailed(Failed failed) {
    enabledIn = false;
    enabledOut = false;
    _unackedQueue.clear();
    base.transport.emit<Failed>('smFailed', data: failed);
  }

  /// Sends the current ack count to the server.
  void _handleRequestAck(StanzaBase stanza) {
    final ack = Ack();
    ack['h'] = handled;
    base.transport.sendRaw(ack.toString());
  }

  /// Processes a server ack by freeing acked stanzas from the queue.
  void _handleAck(StanzaBase stanza) {
    if (stanza['h'] == lastAck) {
      return;
    }

    int numAcked = ((stanza['h'] as int) - lastAck) % _maxSeq;
    final numUnacked = _unackedQueue.length;
    Log.instance.debug(
      'Ack: ${stanza['h']}, Last ack: $lastAck, Unacked: $numUnacked, Num acked: $numAcked, Remaining: ${numUnacked - numAcked}',
    );

    if ((numAcked > _unackedQueue.length) || numAcked < 0) {
      Log.instance.error(
        'Inconsistent sequence numbers from the server, ignoring and replacing ours with them',
      );
      numAcked = _unackedQueue.length;
    }
    for (int i = 0; i < numAcked; i++) {
      final entries = _unackedQueue.entries;
      final seq = entries.last.key;
      final stanza = entries.last.value;
      _unackedQueue.remove(seq);
      base.transport.emit<StanzaBase>('stanzaAcked', data: stanza);
    }
    lastAck = stanza['h'] as int;
  }

  /// Do not implement.
  @override
  void sessionBind(String? jid) {}

  @override
  void pluginEnd() {
    if (base.isComponent) {
      return;
    }

    // base
    //   ..unregisterFeature('sm', order: 10100)
    //   ..unregisterFeature('sm', order: 9000);
    // base.transport
    //   ..removeEventHandler('disconnected', handler: _disconnected)
    //   ..removeEventHandler('sessionEnd', handler: _sessionEnd)
    //   ..removeFilter(filter: _handleIncoming)
    //   ..removeFilter(filter: _handleOutgoing)
    //   ..removeHandler('Stream Management Enabled')
    //   ..removeHandler('Stream Management Resumed')
    //   ..removeHandler('Stream Management Failed')
    //   ..removeHandler('Stream Management Ack')
    //   ..removeHandler('Stream Management Request Ack')
    //   ..removeStanza(Enable())
    //   ..removeStanza(Enabled())
    //   ..removeStanza(Resume())
    //   ..removeStanza(Resumed())
    //   ..removeStanza(Ack())
    //   ..removeStanza(RequestAck());
  }
}
