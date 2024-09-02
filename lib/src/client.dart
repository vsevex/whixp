import 'package:whixp/src/exception.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/jid/jid.dart';
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
  /// authenticating the client.
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
  /// If [pingKeepAlive] is true, then socket periodically sends a
  /// whitespace character over the wire to keep the connection alive.
  ///
  /// [pingKeepAliveInterval] indicates the default interval between keepalive
  /// signals when [pingKeepAlive] is enabled. Represents in seconds. Defaults
  /// to `300`.
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
  /// [context] is a [SecurityContext] instance that is responsible for
  /// certificate exchange.
  ///
  /// [onBadCertificateCallback] passes [X509Certificate] instance when
  /// returning boolean value which indicates to proceed on bad certificate or
  /// not.
  ///
  /// If [reconnectionPolicy] is defined, then [Whixp] tries to reconnect
  /// whenever there is an error (internal, network, etc.). Defaults to `null`.
  ///
  /// ### Example:
  /// ```dart
  /// final whixp = Whixp('vsevex@localhost', 'passwd');
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
    super.endSessionOnDisconnect,
    super.reconnectionPolicy,
    String language = 'en',
  }) {
    _language = language;

    /// Automatically calls the setup callback to configure the XMPP client.
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
        await transport.connection.startTLS();
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
      host = transport.connection.configuration.host;
    } else {
      host = transport.boundJID!.host;
    }

    /// Set [streamHeader] of declared transport for initial send.
    transport
      ..streamHeader =
          "<stream:stream to='$host' xmlns:stream='$streamNamespace' xmlns='$defaultNamespace' xml:lang='$_language' version='1.0'>"
      ..streamFooter = "</stream:stream>";

    final fullJID = session?.bindJID?.full ?? transport.boundJID!.full;

    transport
      ..registerHandler(
        Handler('SM Request', (packet) => session?.sendAnswer())
          ..packet('sm:request'),
      )
      ..registerHandler(
        Handler('SM Answer', (packet) => session?.handleAnswer(packet, fullJID))
          ..packet('sm:answer'),
      )
      ..addEventHandler('startSession', (_) => session?.enabledOut = true)
      ..addEventHandler('endSession', (_) => session?.clearSession())
      ..addEventHandler(
        'increaseHandled',
        (_) => session?.increaseInbound(fullJID),
      );
  }

  void _reset() => streamFeatureHandlers.clear();

  /// Default language to use in stanza communication.
  late final String _language;

  /// Callable function that is triggered when stream is enabled.
  Future<void> _onStreamEnabled(Packet packet) async {
    if (packet is! SMEnabled) return;
    await session?.saveSMState(
      session?.bindJID?.full ?? transport.boundJID!.full,
      SMState(packet.id!, 0, 0, 0),
    );
  }

  Future<bool> _handleStreamFeatures(Packet features) async {
    if (features is! StreamFeatures) return false;
    if (transport.connection.configuration.disableStartTLS &&
        features.tlsRequired) {
      AuthenticationException.requiresTLS();
    }
    if (!transport.connection.configuration.disableStartTLS &&
        !features.tlsRequired) {
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
          session?.bindJID?.full ?? transport.boundJID!.full,
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

        if (result) return true;
      }
    }

    Log.instance.info('Finished processing stream features.');

    transport.emit('streamNegotiated');
    return false;
  }

  /// Connects to the XMPP server.
  ///
  /// When no address is given, a SRV lookup for the server will be attempted.
  /// If that fails, the server user in the JID will be used.
  void connect() => transport
    ..registerHandler(
      Handler('Stream Features', _handleStreamFeatures)
        ..packet('stream:features'),
    )
    ..connect();
}
