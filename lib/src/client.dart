import 'package:whixp/src/exception.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/features.dart';
import 'package:whixp/src/session.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/whixp.dart';

class Whixp extends WhixpBase {
  /// Client class for [Whixp].
  ///
  /// Extends [WhixpBase] class and represents an XMPP client with additional
  /// functionalities.
  ///
  /// [jabberID] associated with the client. This is a required parameter and
  /// should be a valid [JabberID]. Alongside the [jabberID] the [password] for
  /// authenticating the client. This is a required parameter and should be the
  /// password associated with the provided [jabberID].
  ///
  /// [host] is a server's host address. This parameter is optional and defaults
  /// to the value defined in the [WhixpBase].
  ///
  /// [port] is the port number for the server. This parameter is optional and
  /// defaults to the value defined in the [WhixpBase].
  ///
  /// [language] is a default language to use in stanza communication. Defaults
  /// to `en`.
  ///
  /// Timeout for establishing the connection (in milliseconds) is represented
  /// by the [connectionTimeout] parameter. Defaults to `2000`.
  ///
  /// If [whitespaceKeepAlive] is true, then socket periodically send a
  /// whitespace character over the wire to keep the connection alive.
  ///
  /// The default interval between keepalive signals when [whitespaceKeepAlive]
  /// is enabled. Represents in seconds. Defaults to `300`.
  ///
  /// If [useIPv6] is set to `true`, attempts to use IPv6 when connecting.
  ///
  /// [useTLS] is the DirectTLS activator. Defaults to `false`.
  ///
  /// [disableStartTLS] defines whether the client will later call StartTLS or
  /// not.
  ///
  /// When connecting to the server, there can be StartTLS handshaking and
  /// when the client and server try to handshake, we need to upgrade our
  /// connection. This flag disables that handshaking and forbids establishing
  /// a TLS connection on the client side. Defaults to `false`.
  ///
  /// [endSessionOnDisconnect] controls if the session can be considered ended
  /// if the connection is terminated. Defaults to `true`.
  ///
  /// [logger] is a [Log] instance to print out various log messages properly.
  ///
  /// [context] is a [io.SecurityContext] instance that is responsible for
  /// certificate exchange.
  ///
  /// [onBadCertificateCallback] passes [io.X509Certificate] instance when
  /// returning boolean value which indicates to proceed on bad certificate or
  /// not.
  ///
  /// ### Example:
  /// ```dart
  /// final whixp = Whixp('vsevex@example.com', 'passwd');
  /// whixp.connect();
  /// ```
  Whixp({
    super.jabberID,
    String? password,
    super.host,
    super.port,
    super.connectionTimeout,
    super.useIPv6,
    super.useTLS,
    super.disableStartTLS,
    super.pingKeepAlive,
    super.pingKeepAliveInterval,
    super.logger,
    super.context,
    super.onBadCertificateCallback,
    super.internalDatabasePath,
    super.reconnectionPolicy,
    String language = 'en',
  }) {
    _language = language;

    /// Automatically calls the `_setup()` method to configure the XMPP client.
    _setup();

    if (password?.isNotEmpty ?? false) {
      credentials.addAll({'password': password!});
    }
  }

  void _setup() {
    _reset();

    final mechanisms = FeatureMechanisms(this)..pluginInitialize();
    registerFeature(
      'starttls',
      (_) async {
        await transport.startTLS();
        final result = StartTLS.handleStartTLS();
        return result;
      },
      order: 10,
    );
    registerFeature(
      'mechanisms',
      mechanisms.handleSASLAuth,
      restart: true,
      order: 50,
    );

    late String host;

    if (transport.boundJID == null) {
      host = transport.host;
    } else {
      host = transport.boundJID!.host;
    }

    /// Set [streamHeader] of declared transport for initial send.
    transport
      ..streamHeader =
          "<stream:stream to='$host' xmlns:stream='$streamNamespace' xmlns='$defaultNamespace' xml:lang='$_language' version='1.0'>"
      ..streamFooter = "</stream:stream>";

    final fullJID = session?.bindJID?.full ?? transport.boundJID?.full ?? '';

    transport
      ..registerHandler(
        Handler('Stream Features', _handleStreamFeatures)
          ..packet('stream:features'),
      )
      ..registerHandler(
        Handler('SM Request', (packet) => session?.sendAnswer())
          ..packet('sm:request'),
      )
      ..registerHandler(
        Handler('SM Answer', (packet) => session?.handleAnswer(packet, fullJID))
          ..packet('sm:answer'),
      )
      ..addEventHandler('startSession', (_) => session?.enabledOut = true)
      ..addEventHandler('endSession', (_) => session?.enabledOut = false)
      ..addEventHandler(
        'increaseHandled',
        (_) => session?.increaseInbound(fullJID),
      );

    //   ..addEventHandler<JabberID>(
    //     'sessionBind',
    //     (jid) => _handleSessionBind(jid!),
    //   )
    //   ..addEventHandler<IQ>('rosterUpdate', (iq) => _handleRoster(iq!));
    // ..registerHandler(
    //   CallbackHandler(
    //     'Roster Update',
    //     (iq) {
    //       final JabberID? from;
    //       try {
    //         from = iq.from;
    //         if (from != null &&
    //             from.toString().isNotEmpty &&
    //             from.toString() != transport.boundJID.bare) {
    //           final reply = (iq as IQ).replyIQ();
    //           reply['type'] = 'error';
    //           final error = reply['error'] as StanzaError;
    //           error['type'] = 'cancel';
    //           error['code'] = 503;
    //           error['condition'] = 'service-unavailable';
    //           reply.sendIQ();
    //           return;
    //         }
    //         transport.emit<IQ>('rosterUpdate', data: iq as IQ);
    //       } on Exception {
    //         transport.emit<IQ>('rosterUpdate', data: iq as IQ);
    //       }
    //     },
    //     matcher: StanzaPathMatcher('iq@type=set/roster'),
    //   ),
    // );

    transport.defaultLanguage = _language;
  }

  void _reset() => streamFeatureHandlers.clear();

  /// Default language to use in stanza communication.
  late final String _language;

  /// Callable function that is triggered when stream is enabled.
  Future<void> _onStreamEnabled(Packet packet) async {
    if (packet is! SMEnabled) return;
    await session?.saveSMState(
      session?.bindJID?.full ?? transport.boundJID?.full,
      SMState(packet.id!, 0, 0, 0),
    );
  }

  Future<bool> _handleStreamFeatures(Packet features) async {
    if (features is! StreamFeatures) return false;
    if (transport.disableStartTLS && features.tlsRequired) {
      AuthenticationException.requiresTLS();
    }
    if (!transport.disableStartTLS && !features.tlsRequired) {
      AuthenticationException.disabledTLS();
    }

    /// Attach new [Session] manager for this connection.
    session = Session(features);
    if (StreamFeatures.supported.contains('mechanisms')) {
      /// If sm is not supported by the server, then add binding feature.
      if (!features.doesStreamManagement) {
        registerFeature('bind', (_) => session!.bind(), order: 150);
      }
      registerFeature(
        'sm',
        (_) => session!.resume(
          session?.bindJID?.full ?? transport.boundJID?.full,
          onResumeDone: () => transport
            ..removeHandler('SM Resume Handler')
            ..removeHandler('SM Enable Handler'),
          onResumeFailed: () {
            Log.instance.warning('Stream resumption failed');
            return session!.enableStreamManagement(_onStreamEnabled);
          },
        ),
        order: 100,
      );
    }

    for (final feature in streamFeatureOrder) {
      final name = feature.secondValue;

      if (StreamFeatures.list.contains(name)) {
        final handler = streamFeatureHandlers[name]!.firstValue;

        final result = await handler.call(features);

        /// Using delay, 'cause establishing connection may require time,
        /// and if there is something to do with event handling, we should have
        /// time to do necessary things. (e.g. registering user before sending
        /// auth challenge to the server)
        // await Future.delayed(const Duration(milliseconds: 150));
        if (result) return true;
      }
    }

    Log.instance.info('Finished processing stream features.');
    transport.emit('streamNegotiated');
    return false;
  }

  // void _handleSessionBind(JabberID jid) =>
  //     clientRoster = roster[jid.bare] as rost.RosterNode;

  // /// Adds or changes a roster item.
  // ///
  // /// [jid] is the entry to modify.
  // FutureOr<IQ?> updateRoster<T>(
  //   String jid, {
  //   String? name,
  //   String? subscription,
  //   List<String>? groups,
  //   FutureOr<T> Function(IQ iq)? callback,
  //   FutureOr<void> Function(StanzaError error)? failureCallback,
  //   FutureOr<void> Function()? timeoutCallback,
  //   int timeout = 10,
  // }) {
  //   final current = clientRoster[jid] as rost.RosterItem;

  //   name ??= current['name'] as String;
  //   subscription ??= current['subscription'] as String;
  //   groups ??= (current['groups'] as List).isEmpty
  //       ? null
  //       : current['groups'] as List<String>;

  //   return clientRoster.update(
  //     jid,
  //     name: name,
  //     groups: groups,
  //     subscription: subscription,
  //     callback: callback,
  //     failureCallback: failureCallback,
  //     timeoutCallback: timeoutCallback,
  //     timeout: timeout,
  //   );
  // }

  // void _handleRoster(IQ iq) {
  //   if (iq['type'] == 'set') {
  //     final JabberID? from;
  //     try {
  //       from = iq.from;
  //       if (from != null &&
  //           from.bare.isNotEmpty &&
  //           from.bare != transport.boundJID.bare) {
  //         throw StanzaException.serviceUnavailable(iq);
  //       }
  //     } on Exception {
  //       /// pass;
  //     }
  //   }

  //   if (((iq['roster'] as Roster).copy()['ver'] as String).isNotEmpty) {
  //     clientRoster.version = (iq['roster'] as Roster)['ver'] as String;
  //   }
  //   final items =
  //       (iq['roster'] as Roster)['items'] as Map<String, Map<String, dynamic>>;

  //   final validSubscriptions = <String>{'to', 'from', 'both', 'none', 'remove'};
  //   for (final item in items.entries) {
  //     final value = item.value;
  //     final rosterItem = clientRoster[item.key] as rost.RosterItem;
  //     if (validSubscriptions.contains(value['subscription'])) {
  //       rosterItem['name'] = value['name'];
  //       rosterItem['groups'] = value['groups'];
  //       rosterItem['from'] =
  //           <String>{'from', 'both'}.contains(value['subscription'] as String);
  //       rosterItem['to'] =
  //           <String>{'to', 'both'}.contains(value['subscription'] as String);
  //       rosterItem['pending_out'] = value['ask'] == 'subscribe';

  //       rosterItem.save(remove: value['subscription'] == 'remove');
  //     }
  //   }

  //   if (iq['type'] == 'set') {
  //     final response = IQ(
  //       stanzaType: 'result',
  //       stanzaTo: iq.from ?? transport.boundJID,
  //       stanzaID: iq['id'] as String,
  //       transport: transport,
  //     )..enable('roster');
  //     response.sendIQ();
  //   }
  // }

  /// Connects to the XMPP server.
  ///
  /// When no address is given, a SRV lookup for the server will be attempted.
  /// If that fails, the server user in the JID will be used.
  void connect() => transport.connect();
}
