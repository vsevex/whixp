part of 'transport.dart';

class Connection {
  /// Manages the network connection to a server, including DNS resolution,
  /// connection attempts, and reconnection handling. Uses the native (Rust)
  /// transport for TCP/TLS and stanza framing.
  Connection(
    this.configuration,
    this.changeStateCallback, {
    required this.onConnectionStartCallback,
    required this.handleError,
  });

  final ConnectionConfiguration configuration;

  /// Function to invoke whenever there is a [TransportState] change.
  final void Function(TransportState state) changeStateCallback;

  /// The function which is going to be invoked when the connection is
  /// established.
  final Future<void> Function() onConnectionStartCallback;

  /// Error handler callback whenever a connection error occurs.
  final void Function(dynamic exception) handleError;

  /// [async.Completer] of current connection attempt. After the connection,
  /// this [async.Completer] should be equal to null.
  late async.Completer<void>? currentConnectionAttempt;

  /// The event to trigger when the [start] succeeds. It can be
  /// [TransportState.connected] or [TransportState.tlsSuccess] depending on
  /// the step we are at.
  late TransportState _eventWhenConnected;

  /// Domain which will be used for resolution (and display).
  late String _defaultDomain;

  /// Port which will be used when no SRV is found.
  late int _defaultPort;

  /// [Tuple2] type variable that holds both [host] and [port] (for display / retries).
  late Tuple2<String, int> _address;

  /// Resolved host after connect (for SASL). Set from native transport.
  late String serviceName;

  /// Native (Rust) transport handle. Set after [createNativeTransport] and
  /// cleared on disconnect/abort.
  WhixpTransportNative? _native;

  /// since Socket.connect() doesn't return a ConnectionTask.

  /// Will be parsed from [ConnectionConfiguration].
  ReconnectionPolicy? _reconnectionPolicy;

  /// Initialize [Connection] class.
  void initialize({ReconnectionPolicy? reconnectionPolicy}) {
    /// Set reconnection behaviour.
    _reconnectionPolicy = reconnectionPolicy
      ?..performReconnect = () async {
        _rescheduleConnectionAttempt();
        changeStateCallback.call(TransportState.reconnecting);
      };
  }

  /// Creates native transport (Rust does DNS + connect) and starts.
  Future<void> start({void Function()? onConnectionFailure}) async {
    _eventWhenConnected = TransportState.connected;
    await _reconnectionPolicy?.reset();
    await _reconnectionPolicy?.setShouldReconnect(true);

    _address = Tuple2(configuration.host, configuration.port);
    serviceName = configuration.host;

    try {
      Log.instance.info(
        'Connecting to ${configuration.host}:${configuration.port} (DNS in native)',
      );

      changeStateCallback.call(TransportState.connecting);

      _native?.disconnect();
      _native?.destroy();
      _native = null;

      final kind = _nativeKindFromConfiguration;
      _native = configuration.createNativeTransport(
        configuration.host,
        configuration.port,
        kind,
        configuration.connectionTimeout,
        configuration.host,
        configuration.service,
        configuration.useIPv6WhenResolvingDNS,
        configuration.wsPath,
      );
      if (_native == null) {
        throw const WhixpInternalException(
            'createNativeTransport returned null');
      }

      final result = _native!.connect();
      if (result != 0) {
        final message = _native!.lastError;
        throw WhixpInternalException(
          message.isNotEmpty
              ? message
              : 'Native transport connect failed with code $result',
        );
      }
      serviceName = _native!.resolvedHost.isNotEmpty
          ? _native!.resolvedHost
          : configuration.host;
      _native!.startPolling();

      await _onStart();
    } catch (exception) {
      final host = _address.firstValue;
      final port = _address.secondValue;
      final useTLS = configuration.useTLS;
      final disableStartTLS = configuration.disableStartTLS;

      Log.instance.error(
        'Connection error: Failed to connect to $host:$port (TLS: $useTLS, StartTLS disabled: $disableStartTLS)',
      );
      if (exception is WhixpException) {
        Log.instance.error(
          'Connection failed: ${exception.message}. '
          'Host: $host, Port: $port, Service: $serviceName',
        );
      }

      handleError(exception);
      abort(
        callback: onConnectionFailure,
        state: TransportState.connectionFailure,
      );
    }
  }

  int get _nativeKindFromConfiguration {
    if (configuration.useWebSocket) {
      return configuration.useTLS ? kKindWebSocketTls : kKindWebSocket;
    }
    if (configuration.useTLS) return kKindDirectTls;
    if (configuration.disableStartTLS) return kKindTcp;
    return kKindTcpStartTls;
  }

  /// Called when the connection has been established with the server.
  Future<void> _onStart() async {
    changeStateCallback.call(_eventWhenConnected);

    currentConnectionAttempt = null;

    try {
      await onConnectionStartCallback.call();
    } catch (exception) {
      Log.instance.error(
        'Error in connection start callback: $exception',
      );
      handleError(exception);
      rethrow;
    }

    await _reconnectionPolicy?.onSuccess();
  }

  /// Close the XML stream and wait for ack from the server for at most
  /// given milliseconds. After the given number of milliseconds have passed
  /// without a response from the server, or when the server successfully
  /// responds with a closure of its own stream, abort() is called.
  Future<void> hangup({
    bool consume = true,
    bool sendFooter = true,
    Future<void> Function()? consumeCallback,
    String? streamFooter,
  }) async {
    Log.instance.warning('Disconnect method is called');
    await _reconnectionPolicy?.setShouldReconnect(false);
    await _reconnectionPolicy?.reset();
    if (sendFooter && streamFooter != null) send(streamFooter);

    Future<void> consumeSend() async {
      try {
        consumeCallback?.call();
      } on Exception {
        /// pass
      } finally {
        _native?.disconnect();
        _native?.destroy();
        _native = null;
        cancelConnectionAttempt();
        changeStateCallback.call(TransportState.disconnected);
      }
    }

    if (_native != null && consume) {
      return consumeSend();
    } else {
      return abort();
    }
  }

  /// Performs a handshake for TLS. Not used with native transport (TLS is
  /// handled inside Rust for DirectTls / TcpStartTls).
  Future<bool> startTLS() async {
    if (configuration.disableStartTLS) {
      Log.instance
          .info('Disable StartTLS is enabled, can not negotiate handshake');
      return false;
    }
    // Native path: TLS is already negotiated by Rust; no separate StartTLS step.
    return false;
  }

  /// Reschedules current connection attempt when an error occurs.
  void _rescheduleConnectionAttempt() =>
      currentConnectionAttempt = async.Completer()..complete(start());

  void reset({String? host, int? port}) {
    _parseConnectionConfiguration(newHost: host, newPort: port);
    _eventWhenConnected = TransportState.connected;
    _native?.destroy();
    _native = null;
  }

  /// Forcibly close the connection.
  void abort({
    void Function()? callback,
    TransportState state = TransportState.killed,
  }) {
    final hadNative = _native != null;
    if (hadNative) {
      try {
        _native?.disconnect();
        _native?.destroy();
        _native = null;
      } catch (_) {
        Log.instance.error('Native transport not initialized yet, aborting...');
      }
      changeStateCallback.call(state);
    }
    cancelConnectionAttempt();
    callback?.call();
  }

  /// Tear down native transport without emitting state. Use when native
  /// already reported disconnect (e.g. read loop exit) so user got state and
  /// we only need to stop polling and clear handle.
  void tearDownNative() {
    if (_native == null) return;
    try {
      _native?.disconnect();
      _native?.destroy();
    } catch (_) {
      Log.instance.error('Native transport tearDown failed');
    }
    _native = null;
  }

  /// Immediately cancel the current connection attempt.
  void cancelConnectionAttempt() {
    currentConnectionAttempt = null;
    _native?.disconnect();
    _native?.destroy();
    _native = null;
  }

  void _parseConnectionConfiguration({String? newHost, int? newPort}) {
    _defaultDomain = newHost ?? configuration.host;
    _defaultPort = newPort ?? configuration.port;
    _address = Tuple2(_defaultDomain, _defaultPort);
  }

  /// Send raw data using native transport.
  void send(String data) {
    if (_native == null) {
      Log.instance.error('Cannot send data: native transport is null');
      return;
    }

    final raw = WhixpUtils.utf8Encode(data);
    Log.instance.debug(
        '[STANZA_TX] connection.send -> ${data.length} chars (${data.length > 200 ? "${data.substring(0, 200)}..." : data})');

    _native!.send(raw);
  }

  /// Use this method if there is a need to explicitly set reconnection.
  Future<void>? setShouldReconnect(bool value) =>
      _reconnectionPolicy?.setShouldReconnect(value);

  /// Indicates whether the connection is secured (TLS). Native transport uses
  /// TLS when kind is DirectTls or TcpStartTls after handshake.
  bool get isConnectionSecure => _native != null;
}

/// Factory that creates a native transport. Rust performs DNS (SRV + A/AAAA) and connect.
typedef CreateNativeTransport = WhixpTransportNative? Function(
  String host,
  int port,
  int kind,
  int connectTimeoutMs,
  String? tlsServerName,
  String? service,
  bool useIPv6,
  String? wsPath,
);

class ConnectionConfiguration {
  /// Stores the configuration settings for a [Connection] instance. Uses
  /// native (Rust) transport for TCP/TLS/WebSocket and stanza framing.
  const ConnectionConfiguration({
    required this.host,
    required this.port,
    required this.connectionTimeout,
    required this.createNativeTransport,
    required this.disableStartTLS,
    required this.useTLS,
    required this.useIPv6WhenResolvingDNS,
    this.service,
    this.useWebSocket = false,
    this.wsPath,
  });

  /// The host to connect to.
  final String host;

  /// The port to connect to.
  final int port;

  /// Represents the duration in milliseconds for which the system will wait
  /// for a connection to be established before raising a
  /// [async.TimeoutException].
  final int connectionTimeout;

  /// Creates the native transport for (host, port, kind, timeout, tlsName, wsPath).
  final CreateNativeTransport createNativeTransport;

  /// Defines whether the client will later call StartTLS or not.
  ///
  /// When connecting to the server, there can be StartTLS handshaking and
  /// when the client and server try to handshake, we need to upgrade our
  /// connection. This flag disables that handshaking and forbids establishing
  /// a TLS connection on the client side.
  final bool disableStartTLS;

  /// Enable connecting to the server directly over TLS, in particular when the
  /// service provides two ports: one for TCP traffic and another for TLS
  /// traffic.
  final bool useTLS;

  /// If set to `true`, Whixp tries to parse IPv6 instead IPv6 when doing DNS
  /// lookup.
  final bool useIPv6WhenResolvingDNS;

  /// The service name to check with DNS SRV records. For example, setting this
  /// to "xmpp-client" will query the "_xmpp-clilent._tcp" service.
  final String? service;

  /// If `true`, connect over WebSocket (ws:// or wss://) instead of raw TCP/TLS.
  final bool useWebSocket;

  /// WebSocket path (e.g. "/ws" or "/xmpp-websocket"). Only used when [useWebSocket] is true. Defaults to "/ws".
  final String? wsPath;

  @override
  int get hashCode => Object.hashAll([
        host,
        port,
        connectionTimeout,
        createNativeTransport,
        disableStartTLS,
        useTLS,
        useIPv6WhenResolvingDNS,
        service,
        useWebSocket,
        wsPath,
      ]);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is ConnectionConfiguration &&
        other.host == host &&
        other.port == port &&
        other.connectionTimeout == connectionTimeout &&
        other.createNativeTransport == createNativeTransport &&
        other.disableStartTLS == disableStartTLS &&
        other.useTLS == useTLS &&
        other.useIPv6WhenResolvingDNS &&
        other.service == service &&
        other.useWebSocket == useWebSocket &&
        other.wsPath == wsPath;
  }
}
