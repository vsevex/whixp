import 'dart:async';

import 'package:dartz/dartz.dart';

import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/plugins/disco/disco.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/stream/matcher/matcher.dart';

part 'stanza.dart';

/// Given that XMPP is reliant on TCP connections, the underlying connection may
/// be canceled without the application's knowledge. For identifying broken
/// connections, ping stanzas are an alternative to whitespace-based keepalive
/// approaches.
///
/// see <http://www.xmpp.org/extensions/xep-0199.html>
class Ping extends PluginBase {
  Ping({
    /// Time between keepalive pings. Represented in seconds. Defaults to `300`.
    int interval = 300,

    /// Indicates the waiting time for a ping response. Defaults to `30` (in
    /// seconds)
    int timeout = 30,

    /// Indicates whether periodically send ping requests to the server.
    ///
    /// If a ping is not answered, the connection will be reset. Defaults to
    /// `false`.
    bool keepalive = false,
  }) : super(
          'ping',
          description: 'XEP-0199: XMPP Ping',
          dependencies: {'disco'},
        ) {
    _interval = interval;
    _timeout = timeout;
    _keepAlive = keepalive;
  }

  /// time between keepalive pings. Represented in seconds. Defaults to `300`.
  late final int _interval;

  /// Indicates the waiting time for a ping response. Defaults to `30` (in
  /// seconds).
  late final int _timeout;

  /// Indicates whether periodically send ping requests to the server.
  ///
  /// If a ping is not answered, the connection will be reset. Defaults to
  /// `false`.
  late final bool _keepAlive;

  late final IQ _iq;
  late List<Task> _pendingTasks;

  @override
  void pluginInitialize() {
    _iq = IQ(transport: base.transport);

    _pendingTasks = <Task>[];

    base.transport.registerHandler(
      CallbackHandler(
        'Ping',
        (iq) => _handlePing(iq as IQ),
        matcher: StanzaPathMatcher('iq@type=get/ping'),
      ),
    );

    if (_keepAlive) {
      base
        ..addEventHandler('sessionStart', (_) => _enableKeepalive())
        ..addEventHandler('sessionResume', (_) => _enableKeepalive())
        ..addEventHandler<String>('disconnected', (_) => _disableKeepalive());
    }
  }

  /// Cancels all pending ping features.
  void _clearPendingFeatures() {
    if (_pendingTasks.isNotEmpty) {
      Log.instance.debug('Clearing $_pendingTasks pending pings');
      for (final task in _pendingTasks) {
        _pendingTasks.remove(task);
      }
      _pendingTasks.clear();
    }
  }

  void _enableKeepalive() {
    void handler() {
      final temp = <Task>[];
      if (_pendingTasks.isNotEmpty) {
        for (final task in _pendingTasks) {
          task.run();
          temp.add(task);
        }
      }
      for (final task in temp) {
        _pendingTasks.remove(task);
      }

      _pendingTasks.add(Task(_keepalive));
    }

    handler.call();

    base.transport.schedule(
      'pingalive',
      handler,
      seconds: _interval,
      repeat: true,
    );
  }

  void _disableKeepalive() {
    _clearPendingFeatures();
    base.transport.cancelSchedule('pingalive');
  }

  Future<void> _keepalive() async {
    Log.instance.info('Keepalive ping is called');

    await ping(
      jid: base.transport.boundJID,
      iqFrom: base.transport.boundJID,
      timeout: _timeout,
      timeoutCallback: (_) {
        Log.instance.debug(
          'Did not receive ping back in time.\nRequesting reconnection',
        );
        base.transport.reconnect();
      },
    );
  }

  /// Sends a ping request.
  ///
  /// [timeout] represents callback waiting timeout in `seconds`.
  FutureOr<IQ> sendPing(
    JabberID jid, {
    JabberID? iqFrom,
    FutureOr<void> Function(IQ stanza)? callback,
    FutureOr<void> Function(StanzaError stanza)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int? timeout,
  }) {
    _iq['type'] = 'get';
    _iq['to'] = jid.toString();
    if (iqFrom != null) {
      _iq['from'] = iqFrom.toString();
    }
    _iq.enable('ping');

    timeout ??= _timeout;

    return _iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Sends a ping request and calculates Round Trip Time (RTT).
  Future<IQ?> ping({
    JabberID? jid,
    JabberID? iqFrom,
    FutureOr<void> Function(StanzaBase stanza)? timeoutCallback,
    int? timeout,
  }) async {
    bool ownHost = false;
    late String rawJID = jid.toString();
    if (jid == null) {
      if (base.isComponent) {
        rawJID = base.transport.boundJID.server;
      } else {
        rawJID = base.transport.boundJID.host;
      }
    }

    if (rawJID == base.transport.boundJID.host ||
        (base.isComponent && rawJID == base.transport.boundJID.server)) {
      ownHost = true;
    }

    timeout ??= _timeout;

    final start = DateTime.now();
    late int rtt;

    Log.instance.debug('Pinging "$rawJID"');

    try {
      return sendPing(
        JabberID(rawJID),
        iqFrom: iqFrom,
        timeout: timeout,
        failureCallback: (stanza) {
          if (ownHost) {
            rtt = DateTime.now().difference(start).inSeconds;
            Log.instance
                .debug('Pinged "$rawJID", Round Trip Time in seconds: $rtt');
          }
        },
      );
    } on Exception {
      final rtt = DateTime.now().difference(start).inSeconds;
      Log.instance.debug('Pinged "$rawJID", Round Trip Time in seconds: $rtt');
      return null;
    }
  }

  /// Automatically reply to ping requests.
  void _handlePing(IQ iq) {
    Log.instance.debug('Ping by ${iq['from']}');
    iq.replyIQ()
      ..transport = base.transport
      ..sendIQ();
  }

  @override
  void pluginEnd() {
    final disco = base.getPluginInstance<ServiceDiscovery>(
      'disco',
      enableIfRegistered: false,
    );
    if (disco != null) {
      disco.removeFeature(PingStanza().namespace);
    }

    base.transport.removeHandler('Ping');
    if (_keepAlive) {
      base.transport
        ..removeEventHandler('sessionStart', handler: _enableKeepalive)
        ..removeEventHandler('sessionResume', handler: _enableKeepalive)
        ..removeEventHandler('disconnected', handler: _disableKeepalive);
    }
  }

  @override
  void sessionBind(String? jid) {
    final disco = base.getPluginInstance<ServiceDiscovery>('disco');
    if (disco != null) {
      disco.addFeature(PingStanza().namespace);
    }
  }
}
