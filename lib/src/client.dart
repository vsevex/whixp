import 'package:whixp/src/exception.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/features.dart';
import 'package:whixp/src/session.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/whixp.dart';

class Whixp extends WhixpBase {
  /// Stable key used for Stream Management (XEP-0198) persistence/resumption.
  ///
  /// Must NOT include the resource, since the resource may change between
  /// connections and is not available prior to stream resumption.
  String? _jidKey() => session?.bindJID?.bare ?? transport.boundJID?.bare;

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
  /// [logger] is a [Log] instance to print out various log messages properly.
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
    super.useWebSocket,
    super.wsPath,
    super.pingKeepAlive,
    super.pingKeepAliveInterval,
    super.logger,
    super.internalDatabasePath,
    super.reconnectionPolicy,
    String language = 'en',
  }) {
    _language = language;

    /// Automatically calls the setup callback to configure the XMPP client.
    _setup();

    if (password?.isNotEmpty ?? false) {
      credentials.addAll({'password': password});
    }
  }

  void _setup() {
    _reset();

    final mechanisms = FeatureMechanisms(this)..pluginInitialize();
    registerFeature(
      'starttls',
      (_) async {
        await transport.connection.startTLS();
        final result = StartTLS.handleStartTLS(transport);
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
    /// Over WebSocket (RFC 7395) use <open>/<close> framing; otherwise <stream:stream>.
    if (transport.useWebSocket) {
      transport
        ..streamHeader =
            "<open xmlns='urn:ietf:params:xml:ns:xmpp-framing' to='$host' version='1.0' xml:lang='$_language'/>"
        ..streamFooter = "<close xmlns='urn:ietf:params:xml:ns:xmpp-framing'/>";
    } else {
      transport
        ..streamHeader =
            "<stream:stream to='$host' xmlns:stream='$streamNamespace' xmlns='$defaultNamespace' xml:lang='$_language' version='1.0'>"
        ..streamFooter = "</stream:stream>";
    }

    transport
      ..registerHandler(
        Handler('SM Request', (packet) => session?.sendAnswer())
          ..packet('sm:request'),
      )
      ..registerHandler(
        Handler(
            'SM Answer', (packet) => session?.handleAnswer(packet, _jidKey()))
          ..packet('sm:answer'),
      )
      ..addEventHandler('startSession', (_) => session?.enabledOut = true)
      ..addEventHandler('endSession', (_) => session?.clearSession())
      ..addEventHandler(
        'increaseHandled',
        (_) => session?.increaseInbound(_jidKey()),
      );
  }

  void _reset() => streamFeatureHandlers.clear();

  /// Default language to use in stanza communication.
  late final String _language;

  /// Callable function that is triggered when stream is enabled.
  Future<void> _onStreamEnabled(Packet packet) async {
    if (packet is! SMEnabled) return;
    final key = _jidKey();
    if (key?.isEmpty ?? true) return;
    await session?.saveSMState(key, SMState(packet.id!, 0, 0, 0));
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
    session = Session(features, transport);
    if (StreamFeatures.supported.contains('mechanisms')) {
      /// If sm is not supported by the server, then add binding feature.
      if (!features.doesStreamManagement) {
        registerFeature('bind', (_) => session!.bind(), order: 150);
      }
      registerFeature(
        'sm',
        (_) async {
          // Try stream resumption BEFORE binding.
          // If resumption succeeds, the previously bound resource is resumed and
          // re-binding is unnecessary.
          final key = _jidKey();
          if (key?.isEmpty ?? true) {
            Log.instance
                .warning('Cannot attempt SM resume: no JID key available');
            return false;
          }

          return await session!.resume(
            key,
            onResumeDone: () => transport
              ..removeHandler('SM Resume Handler')
              ..removeHandler('SM Enable Handler'),
            onResumeFailed: () async {
              Log.instance.warning(
                  'Stream resumption failed, enabling stream management...');
              // For first-time SM enable we need to bind a resource.
              if (session!.bindJID == null) {
                Log.instance.info(
                    'Binding resource before enabling stream management...');
                await session!.bind();
              }
              final result =
                  await session!.enableStreamManagement(_onStreamEnabled);
              Log.instance.info(
                  'Stream management enable completed with result: $result');
              return result;
            },
          );
        },
        order: 100,
      );
    }

    for (final feature in streamFeatureOrder) {
      final name = feature.secondValue;

      if (StreamFeatures.list.contains(name)) {
        final handlerTuple = streamFeatureHandlers[name]!;
        final handler = handlerTuple.firstValue;
        final restart = handlerTuple.secondValue; // restart flag

        final result = await handler.call(features);

        // If handler returns true AND has restart flag, return early
        // because the stream will restart and we'll get new features
        // Otherwise, continue processing to emit streamNegotiated
        if (result && restart) {
          Log.instance.info(
              'Feature $name processed successfully, stream will restart');
          return true;
        }

        if (result) {
          Log.instance.info('Feature $name processed successfully');
        }
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
