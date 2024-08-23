part of 'transport.dart';

class Connection {
  /// Manages the network connection to a server, including DNS resolution,
  /// connection attempts, and reconnection handling. It uses a combination of
  /// DNS SRV records and direct host/port configurations to establish a
  /// connection.
  ///
  /// The class also supports TLS (Transport Layer Security) for secure
  /// connections and provides methods to handle connection state changes and
  /// reconnection policies.
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

  /// Error handler callback whenever there is a connection error occured.
  final void Function(dynamic exception) handleError;

  /// [async.Completer] of current connection attempt. After the connection,
  /// this [async.Completer] should be equal to null.
  late async.Completer<void>? currentConnectionAttempt;

  /// The event to trigger when the [start] succeeds. It can be
  /// [TransportState.connected] or [TransportState.tlsSuccess] depending on
  /// the step we are at.
  late TransportState _eventWhenConnected;

  /// Domain which will be used when querying DNS records.
  late String _defaultDomain;

  /// Port which will be used if there is not any answer from the DNS loookup.
  late int _defaultPort;

  /// [Tuple2] type variable that holds both [_host] and [_port].
  late Tuple2<String, int> _address;

  /// [Iterator] of DNS results that have not yet been tried.
  late Iterator<Tuple3<String, String, int>>? _dnsAnswers;

  /// Will hold host that socket is connected to and will work in the
  /// association of SASL.
  late String serviceName;

  /// [Connecta] instance that will be declared when there is a connection
  /// attempt to the server.
  Connecta? _connecta;

  /// [io.ConnectionTask] keeps current connection task and can be used to
  /// cancel when it is necessary.
  late io.ConnectionTask<io.Socket>? _connectionTask;

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

  /// Creates a new socket and connects to the server.
  Future<void> start({void Function()? onConnectionFailure}) async {
    final record = await _parseDNSRecord();
    _eventWhenConnected = TransportState.connected;

    await _reconnectionPolicy?.reset();
    await _reconnectionPolicy?.setShouldReconnect(true);

    if (record != null) {
      final host = record.firstValue;

      /// A fully qualified domain name.
      final fqdn = record.secondValue;
      final port = record.thirdValue;

      _address = Tuple2(fqdn, port);
      serviceName = host;
    } else {
      /// Set to null for no more iteration.
      _dnsAnswers = null;
    }

    /// Sets [Connecta] instance and assigns newly created instance to the
    /// global variable.
    _setConnectaInstance();

    try {
      Log.instance.info(
        'Trying to connect to ${_address.firstValue} on port ${_address.secondValue}',
      );

      changeStateCallback.call(TransportState.connecting);
      _connectionTask =
          await _connecta?.createTask(configuration.socketOptions);

      await _onStart();
    } catch (exception) {
      Log.instance.error(
        'Error occured while trying to connect to ${_address.firstValue}',
      );
      handleError(exception);
      abort(
        callback: onConnectionFailure,
        state: TransportState.connectionFailure,
      );
    }
  }

  /// Called when the connection has been established with the server.
  Future<void> _onStart([bool clearAnswers = false]) async {
    changeStateCallback.call(_eventWhenConnected);

    /// If there is new connection attempt will take place, then this variable
    /// should be null.
    currentConnectionAttempt = null;
    await onConnectionStartCallback.call();

    await _reconnectionPolicy?.onSuccess();
    if (clearAnswers) _dnsAnswers = null;
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
    if (sendFooter && streamFooter != null) send(streamFooter);

    Future<void> consumeSend() async {
      try {
        consumeCallback?.call();
      } on Exception {
        /// pass
      } finally {
        _connecta?.destroy();
        cancelConnectionAttempt();
        changeStateCallback.call(TransportState.disconnected);
      }
    }

    if (_connecta != null && consume) {
      return consumeSend();
    } else {
      return abort();
    }
  }

  void _setConnectaInstance() => _connecta = Connecta(
        ConnectaToolkit(
          hostname: _address.firstValue,
          port: _address.secondValue,
          context: configuration.securityContext,
          timeout: configuration.connectionTimeout,
          connectionType: _connectionTypeFromConfiguration,
          onBadCertificateCallback: configuration.onBadCertificateCallback,
          supportedProtocols: ['TLSv1.2', 'TLSv1.3'],
        ),
      );

  /// Parses [ConnectionType] from the [ConnectionConfiguration].
  ConnectionType get _connectionTypeFromConfiguration {
    if (configuration.useTLS) return ConnectionType.tls;
    if (configuration.disableStartTLS) return ConnectionType.tcp;
    return ConnectionType.upgradableTcp;
  }

  /// Starts parsing SRV records from remote servers. It will return [SRVRecord]
  /// list with corresponding values and an empty list if there is nothing
  /// found.
  Future<List<SRVRecord>> _parseSRVRecords() async {
    ResolveResponse? response;

    final srvs = <SRVRecord>[];
    final service = configuration.service;

    /// Set current [TransportState] to pickingAddress.
    changeStateCallback.call(TransportState.pickingAddress);

    if (service != null) {
      try {
        response = await DNSolve()
            .lookup('_$service._tcp.$_defaultDomain', type: RecordType.srv)
            .timeout(
          const Duration(milliseconds: 5000),
          onTimeout: () {
            throw async.TimeoutException('Connection timed out');
          },
        );
      } catch (_) {
        rethrow;
      }

      if (response.answer != null &&
          (response.answer!.srvs != null &&
              response.answer!.srvs!.isNotEmpty)) {
        for (final record in SRVRecord.sort(response.answer!.srvs!)) {
          if (record.target != null) {
            srvs.add(record);
          }
        }
      }
    }

    return srvs;
  }

  /// Performs DNS resolution for a given hostname.
  ///
  /// Resolution may perform SRV record lookups if a service and protocol are
  /// specified. The returned addresses will be sorted according to the SRV
  /// properties and weights.
  Future<Tuple3<String, String, int>?> _parseDNSRecord() async {
    final srvs = <SRVRecord>[];

    try {
      final result = await _parseSRVRecords();

      /// Add found values to the final [List].
      srvs.addAll(result);
    } on Exception {
      Log.instance.warning('Could not pick any SRV record');
    }

    /// Tuple3 -> (Domain, FQDN, port)
    final results = <Tuple3<String, String, int>>[];

    /// If there is not any answer from SRV records which previously parsed
    /// (tried at least), then stop iteration.
    if (srvs.isEmpty) return null;

    final useIPv6 = configuration.useIPv6WhenResolvingDNS;

    for (final srv in srvs) {
      if (useIPv6) {
        final response =
            await DNSolve().lookup(srv.target!, type: RecordType.aaaa);
        if (response.answer != null && response.answer!.records != null) {
          for (final record in response.answer!.records!) {
            results.add(Tuple3(_defaultDomain, record.name, srv.port));
          }
        }
      }
      final response = await DNSolve().lookup(srv.target!);
      if (response.answer != null) {
        for (final record in response.answer!.records!) {
          results.add(Tuple3(_defaultDomain, record.name, srv.port));
        }
      }
    }

    if (results.isNotEmpty) {
      _dnsAnswers = results.iterator;

      try {
        return _dnsAnswers!.moveNext() ? _dnsAnswers!.current : null;
      } catch (_) {
        return null;
      }
    }

    ResolveResponse? response;

    try {
      if (!useIPv6) {
        Log.instance.warning('DNS lookup: Use of IPv6 has been disabled');
      }

      response = await DNSolve().lookup(
        _defaultDomain,
        type: useIPv6 ? RecordType.aaaa : RecordType.A,
      );
    } catch (_) {
      Log.instance.warning(
        'DNS lookup: Failed to parse${useIPv6 ? ' IPv6 ' : ' '}records for $_defaultDomain, processing with provided record',
      );
      return null;
    }

    if (response.answer != null && response.answer!.records != null) {
      for (final record in response.answer!.records!) {
        results.add(Tuple3(_defaultDomain, record.name, _defaultPort));
      }
    }

    if (results.isNotEmpty) {
      _dnsAnswers = results.iterator;

      try {
        return _dnsAnswers!.moveNext() ? _dnsAnswers!.current : null;
      } catch (_) {
        return null;
      }
    }

    return null;
  }

  /// Performs a handshake for TLS.
  ///
  /// If the handshake is successful, the XML stream will need to be restarted.
  Future<bool> startTLS() async {
    if (_connecta == null) return false;

    if (configuration.disableStartTLS) {
      Log.instance
          .info('Disable StartTLS is enabled, can not negotiate handshake');
      return false;
    }

    _eventWhenConnected = TransportState.tlsSuccess;

    try {
      await _connecta!.upgradeConnection(listener: configuration.socketOptions);

      await _onStart(true);
      return true;
    } on ConnectaException catch (error) {
      Log.instance.error(error.message);
      if (_dnsAnswers != null && _dnsAnswers!.moveNext()) {
        await startTLS();
      } else {
        rethrow;
      }
      return false;
    }
  }

  /// Reschedules current connection attempt if there is an error occured.
  void _rescheduleConnectionAttempt() =>
      currentConnectionAttempt = async.Completer()..complete(start());

  void reset({String? host, int? port}) {
    _parseConnectionConfiguration(newHost: host, newPort: port);
    _eventWhenConnected = TransportState.connected;
    _connecta = null;
    _connectionTask = null;
  }

  /// Forcibly close the connection.
  ///
  /// [callback] will be invoked from [Transport] class if there is something
  /// to do on aborting.
  void abort({
    void Function()? callback,
    TransportState state = TransportState.killed,
  }) {
    if (_connecta != null) {
      try {
        _connecta?.destroy();
      } catch (_) {
        Log.instance.error('Socket is not initialized yet, aborting...');
      }
      changeStateCallback.call(state);
      cancelConnectionAttempt();
    }
    callback?.call();
  }

  /// Immediately cancel the current connection attempt.
  void cancelConnectionAttempt() {
    currentConnectionAttempt = null;
    _connectionTask?.cancel();
    _connecta = null;
  }

  void _parseConnectionConfiguration({String? newHost, int? newPort}) {
    _defaultDomain = newHost ?? configuration.host;
    _defaultPort = newPort ?? configuration.port;
    _address = Tuple2(_defaultDomain, _defaultPort);
  }

  /// Send raw data using socket.
  void send(String data) {
    final raw = WhixpUtils.utf8Encode(data);
    Log.instance.debug('SEND: $data');

    if (_connecta != null) _connecta?.send(raw);
  }

  /// Use this method if there is a need to explicitly set reconnection.
  Future<void>? setShouldReconnect(bool value) =>
      _reconnectionPolicy?.setShouldReconnect(value);

  /// Indicates to the security of connection.
  bool get isConnectionSecure => _connecta?.isConnectionSecure ?? false;
}

class ConnectionConfiguration {
  /// Stores the configuration settings for a [Connection] instance. It defines
  /// the [host], [port], security context, and other parameters needed to
  /// establish a connection, including optional settings for TLS, IPv6, and
  /// reconnection policies.
  const ConnectionConfiguration({
    required this.host,
    required this.port,
    required this.securityContext,
    required this.connectionTimeout,
    required this.socketOptions,
    required this.disableStartTLS,
    required this.useTLS,
    required this.useIPv6WhenResolvingDNS,
    this.service,
    this.onBadCertificateCallback,
  });

  /// The host that socket has to connect to.
  final String host;

  /// The port that socket has to connect to.
  final int port;

  /// Optional [io.SecurityContext] which is going to be used in socket
  /// connections.
  final io.SecurityContext? securityContext;

  /// Represents the duration in milliseconds for which the system will wait
  /// for a connection to be established before raising a
  /// [async.TimeoutException].
  final int connectionTimeout;

  /// Part of [Connecta] package. Used to handle state of socket connection and
  /// do required actions.
  final ConnectaListener socketOptions;

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

  /// To avoid processing on bad certification you can use this callback.
  ///
  /// Passes [io.X509Certificate] instance when returning boolean value which
  /// indicates to proceed on bad certificate or not.
  final bool Function(io.X509Certificate cert)? onBadCertificateCallback;

  @override
  int get hashCode => Object.hashAll([
        host,
        port,
        securityContext,
        connectionTimeout,
        socketOptions,
        disableStartTLS,
        useTLS,
        useIPv6WhenResolvingDNS,
        service,
        onBadCertificateCallback,
      ]);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is ConnectionConfiguration &&
        other.host == host &&
        other.port == port &&
        other.securityContext == securityContext &&
        other.connectionTimeout == connectionTimeout &&
        other.socketOptions == socketOptions &&
        other.disableStartTLS == disableStartTLS &&
        other.useTLS == useTLS &&
        other.useIPv6WhenResolvingDNS &&
        other.service == service &&
        other.onBadCertificateCallback == onBadCertificateCallback;
  }
}
