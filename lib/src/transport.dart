import 'dart:async' as async;
import 'dart:io' as io;

import 'package:connecta/connecta.dart';
import 'package:dnsolve/dnsolve.dart';
import 'package:synchronized/extension.dart';

import 'package:whixp/src/enums.dart';
import 'package:whixp/src/exception.dart';
import 'package:whixp/src/handler/eventius.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/handler/router.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/parser.dart';
import 'package:whixp/src/plugins/features.dart';
import 'package:whixp/src/reconnection.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/message.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/stanza/presence.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/stream.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// Designed to simplify the complexities associated with establishing a
/// connection to a server, as well as sending and receiving XML stanzas.
///
/// Establishes a socket connection, accepts and sends data over this socket.
class Transport {
  static Transport? _instance;

  /// Typically, stanzas are first processed by a [Transport] event handler
  /// which will then trigger ustom events to continue further processing,
  /// especially since custom event handlers may run in individual threads.
  ///
  /// [Transport] establishes [io.Socket] connection in the first hand, then
  /// initializes XML parser and tries to parse incoming XML's to the particular
  /// stanzas.
  ///
  /// Note: This class should only be used in the associate of [Whixp] client
  /// or component.
  ///
  /// ### Example:
  /// ```dart
  /// final transport = Transport('xmpp.is', port: 5223, useTLS: true);
  /// /// it will connect to the "xmpp.is" on port 5223 over DirectTLS
  /// transport.connect();
  /// ```
  factory Transport(
    /// Hostname that the client needs to establish a connection with
    String host, {
    /// Defaults to 5222
    int port = 5222,

    /// The JabberID (JID) used by this connection, as set after session
    /// binding. This may even be a different bare JID than what was requested
    JabberID? boundJID,

    /// The service name to check with DNS SRV records. For example, setting this
    /// to "xmpp-client" would query the "_xmpp-clilent._tcp" service.
    String? dnsService,

    /// If set to `true`, attempt to use IPv6
    bool useIPv6 = false,

    /// Enable connecting to the server directly over TLS, in particular when the
    /// service provides two ports: one for non-TLS traffic and another for TLS
    /// traffic. Defaults to `false`
    bool useTLS = false,

    /// Defines whether the client will later call StartTLS or not
    ///
    /// When connecting to the server, there can be StartTLS handshaking and
    /// when the client and server try to handshake, we need to upgrade our
    /// connection. This flag disables that handshaking and forbids establishing
    /// a TLS connection on the client side. Defaults to `false`
    bool disableStartTLS = false,

    /// If `true`, periodically send a whitespace character over the wire to
    /// keep the connection alive
    bool pingKeepAlive = true,

    /// The default interval between keepalive signals when [pingKeepAlive] is
    /// enabled. Represents in seconds. Defaults to `180`
    int pingKeepAliveInterval = 180,

    /// Optional [io.SecurityContext] which is going to be used in socket
    /// connections
    io.SecurityContext? context,

    /// To avoid processing on bad certification you can use this callback.
    ///
    /// Passes [io.X509Certificate] instance when returning boolean value which
    /// indicates to proceed on bad certificate or not.
    bool Function(io.X509Certificate)? onBadCertificateCallback,

    /// Represents the duration in milliseconds for which the system will wait
    /// for a connection to be established before raising a
    /// [async.TimeoutException].
    ///
    /// Defaults to `4000` milliseconds
    int connectionTimeout = 4000,
    required ReconnectionPolicy reconnectionPolicy,
  }) {
    if (_instance != null) return _instance!;
    return _instance = Transport._internal(
      host,
      boundJID: boundJID,
      port: port,
      dnsService: dnsService,
      useIPv6: useIPv6,
      useTLS: useTLS,
      disableStartTLS: disableStartTLS,
      pingKeepAlive: pingKeepAlive,
      pingKeepAliveInterval: pingKeepAliveInterval,
      context: context,
      onBadCertificateCallback: onBadCertificateCallback,
      connectionTimeout: connectionTimeout,
      reconnectionPolicy: reconnectionPolicy,
    );
  }

  factory Transport.instance() => _instance!;

  Transport._internal(
    this.host, {
    required int port,
    required this.boundJID,
    required String? dnsService,
    required bool useIPv6,
    required bool useTLS,
    required bool disableStartTLS,
    required this.pingKeepAlive,
    required this.pingKeepAliveInterval,
    required io.SecurityContext? context,
    required bool Function(io.X509Certificate)? onBadCertificateCallback,
    required this.connectionTimeout,
    required ReconnectionPolicy reconnectionPolicy,
  }) {
    _port = port;

    _useTLS = useTLS;
    _disableStartTLS = disableStartTLS;
    _useIPv6 = useIPv6;
    _dnsService = dnsService;

    endSessionOnDisconnect = true;

    streamHeader = '<stream>';
    streamFooter = '<stream/>';

    _context = context ?? io.SecurityContext.defaultContext;

    _onBadCertificateCallback = onBadCertificateCallback;

    _reconnectionPolicy = reconnectionPolicy;

    _setup();
  }

  /// The host that [Whixp] has to connect to.
  final String host;

  /// The port that [Whixp] has to connect to.
  late int _port;

  /// [Tuple2] type variable that holds both [_host] and [_port].
  late Tuple2<String, int> _address;

  /// The JabberID (JID) used by this connection, as set after session binding.
  ///
  /// This may even be a different bare JID than what was requested.
  JabberID? boundJID;

  /// Will hold host that [Whixp] is connected to and will work in the
  /// association of [SASL].
  late String serviceName;

  /// [Connecta] instance that will be declared when there is a connection
  /// attempt to the server.
  Connecta? _connecta;

  /// [Eventius] type variable that holds actual event manager.
  late Eventius _eventius;

  /// Scheduled callback handler [Map] late initializer.
  late Map<String, async.Timer> _scheduledEvents;

  /// Enable connecting to the server directly over TLS, in particular when the
  /// service provides two ports: one for non-TLS traffic and another for TLS
  /// traffic.
  late bool _useTLS;

  /// Defines whether the client will later call StartTLS or not.
  ///
  /// When connecting to the server, there can be StartTLS handshaking and
  /// when the client and server try to handshake, we need to upgrade our
  /// connection. This flag disables that handshaking and forbids establishing
  /// a TLS connection on the client side.
  late bool _disableStartTLS;

  /// If set to `true`, attempt to use IPv6.
  late bool _useIPv6;

  /// If `true`, periodically send a whitespace character over the wire to keep
  /// the connection alive.
  final bool pingKeepAlive;

  /// The default interval between keepalive signals when [pingKeepAliveInterval]
  /// is enabled.
  final int pingKeepAliveInterval;

  /// Controls if the session can be considered ended if the connection is
  /// terminated.
  late bool endSessionOnDisconnect;

  /// Default [Timer] for [pingKeepAliveInterval]. This will be assigned when
  /// there is a [Timer] attached after connection established.
  async.Timer? _keepAliveTimer;

  /// The service name to check with DNS SRV records. For example, setting this
  /// to "xmpp-client" would query the "_xmpp-clilent._tcp" service.
  String? _dnsService;

  /// Represents the duration in milliseconds for which the system will wait
  /// for a connection to be established before raising a [TimeoutException].
  final int connectionTimeout;

  /// Optional [io.SecurityContext] which is going to be used in socket
  /// connections.
  late io.SecurityContext? _context;

  /// [StreamController] for [_waitingQueue].
  late async.StreamController<Packet> _waitingQueueController;
  final _queuedStanzas = <Packet>[];

  /// [Completer] of current connection attempt. After the connection, this
  /// [Completer] should be equal to null.
  async.Completer<void>? _currentConnectionAttempt;

  /// Actual [StreamParser] instance to manipulate incoming data from the
  /// socket.
  late StreamParser _parser;

  /// [StreamParser] parser should add list of [StreamObject] to this
  /// controller.
  late async.StreamController<String> _streamController;

  /// [StreamParser] parser will communicate with this [async.Stream];
  late async.Stream<List<StreamObject>> _stream;

  /// [Iterator] of DNS results that have not yet been tried.
  Iterator<Tuple3<String, String, int>>? _dnsAnswers;

  /// The default opening tag for the stream element.
  late String streamHeader;

  /// The default closing tag for the stream element.
  late String streamFooter;

  /// [io.ConnectionTask] keeps current connection task and can be used to
  /// cancel if there is a need.
  io.ConnectionTask<io.Socket>? _connectionTask;

  /// The event to trigger when the [_connect] succeeds. It can be "connected"
  /// or "tlsSuccess" depending on the step we are at.
  late TransportState _eventWhenConnected;

  /// The domain to try when querying DNS records.
  String _defaultDomain = '';

  /// The default namespace of the stream content, not of the stream wrapper it.
  late String defaultNamespace;

  /// Flag that indicates if the socket connection is secure or not.
  late bool _isConnectionSecured;

  /// Indicates to the default language of the streaming.
  String? defaultLanguage;

  /// Indicates to the default langauge of the last peer.
  String? peerDefaultLanguage;

  /// To avoid processing on bad certification you can use this callback.
  ///
  /// Passes [io.X509Certificate] instance when returning boolean value which
  /// indicates to proceed on bad certificate or not.
  bool Function(io.X509Certificate)? _onBadCertificateCallback;

  /// Current redirect attempt. Increases when there is an attempt occurs to
  /// the redirection (see-other-host).
  late int _redirectAttempts;

  /// Indicates if session is started or not.
  bool _sessionStarted = false;

  /// Policy for reconnection, indicates delay between disconnection and
  /// reconnection.
  late final ReconnectionPolicy _reconnectionPolicy;

  /// The list of callbacks that will be triggered before the stanza send.
  final callbacksBeforeStanzaSend =
      <async.FutureOr<void> Function(dynamic data)>[];

  void _setup() {
    _reset();

    _reconnectionPolicy.performReconnect = () async {
      await _rescheduleConnectionAttempt();
      emit<TransportState>('state', data: TransportState.reconnecting);
    };

    addEventHandler<TransportState>('state', (state) async {
      if (state == TransportState.disconnected ||
          state == TransportState.killed) {
        if (_keepAliveTimer != null) {
          Log.instance.warning('Stopping Ping keep alive...');
          _keepAliveTimer?.cancel();
        }
        StreamFeatures.supported.clear();
        await _waitingQueueController.close();
      }
    });
    addEventHandler('startSession', (_) async {
      _setSessionStart();
      _startKeepAlive();
      _sessionStarted = true;
      await _reconnectionPolicy.setShouldReconnect(true);
    });
    addEventHandler('endSession', (_) => _sessionStarted = false);
    addEventHandler('streamNegotiated', (_) => _parser.reset());
  }

  void _reset() {
    serviceName = '';
    _address = Tuple2(host, _port);

    _eventius = Eventius();

    _keepAliveTimer = null;

    _eventWhenConnected = TransportState.connected;
    _redirectAttempts = 0;

    defaultNamespace = '';

    defaultLanguage = null;
    peerDefaultLanguage = null;

    _connecta = null;
    _connectionTask = null;

    _scheduledEvents = <String, async.Timer>{};
  }

  /// Begin sending whitespace periodically to keep the connection alive.
  void _startKeepAlive() {
    Log.instance.info('Starting Ping keep alive...');
    if (pingKeepAlive) {
      _keepAliveTimer = async.Timer.periodic(
        Duration(seconds: pingKeepAliveInterval),
        (_) => send(const SMRequest()),
      );
    }
  }

  /// Creates a new socket and connect to the server.
  ///
  /// The parameters needed to establish a connection in order are passed
  /// beforehand when creating [Transport] instance.
  void connect() {
    _waitingQueueController = async.StreamController<Packet>.broadcast();
    callbacksBeforeStanzaSend.clear();

    _run();
    _cancelConnectionAttempt();

    _defaultDomain = _address.firstValue;

    emit<TransportState>('state', data: TransportState.connecting);
    _currentConnectionAttempt = async.Completer()..complete(_connect());
  }

  void _initParser() {
    _parser = StreamParser();
    _streamController = async.StreamController<String>();
    _stream = _streamController.stream.transform(_parser);
    _stream.listen((objects) async {
      for (final object in objects) {
        if (object is StreamHeader) {
          startStreamHandler(object.attributes);
        } else if (object is StreamElement) {
          final element = object.element;
          if (element.getAttribute('xmlns') == null) {
            if (element.localName == 'message' ||
                element.localName == 'presence' ||
                element.localName == 'iq') {
              element.setAttribute('xmlns', WhixpUtils.getNamespace('CLIENT'));
            } else {
              element.setAttribute(
                'xmlns',
                WhixpUtils.getNamespace('JABBER_STREAM'),
              );
            }
          }

          await _spawnEvent(element);
        } else {
          Log.instance.info('End of stream received.');
          abort();
        }
      }
    });
  }

  Future<void> _connect() async {
    _eventWhenConnected = TransportState.connected;
    _initParser();

    await _reconnectionPolicy.reset();
    await _reconnectionPolicy.setShouldReconnect(true);
    _parser.reset();

    Tuple3<String, String, int>? record;

    try {
      record = await _pickDNSAnswer(_defaultDomain, service: _dnsService);
    } on async.TimeoutException catch (error) {
      Log.instance.warning('Could not pick any SRV record');
      await _handleError(error);
    }

    if (record != null) {
      final host = record.firstValue;
      final address = record.secondValue;
      final port = record.thirdValue;

      _address = Tuple2(address, port);
      serviceName = host;
    } else {
      _dnsAnswers = null;
    }

    if (_useTLS) {
      _connecta = Connecta(
        ConnectaToolkit(
          hostname: _address.firstValue,
          port: _address.secondValue,
          context: _context,
          timeout: connectionTimeout,
          connectionType: ConnectionType.tls,
          onBadCertificateCallback: _onBadCertificateCallback,
          supportedProtocols: ['TLSv1.2', 'TLSv1.3'],
        ),
      );
    } else {
      _connecta = Connecta(
        ConnectaToolkit(
          hostname: _address.firstValue,
          port: _address.secondValue,
          timeout: connectionTimeout,
          context: _context,
          onBadCertificateCallback: _onBadCertificateCallback,
          connectionType: _disableStartTLS
              ? ConnectionType.tcp
              : ConnectionType.upgradableTcp,
          supportedProtocols: ['TLSv1.2', 'TLSv1.3'],
        ),
      );
    }

    try {
      Log.instance.info(
        'Trying to connect to ${_address.firstValue} on port ${_address.secondValue}',
      );

      _connectionTask = await _connecta!.createTask(
        ConnectaListener(
          onData: _dataReceived,
          onError: (exception, trace) async {
            Log.instance.error(
              'Connection error occured.',
              exception: exception,
              stackTrace: trace as StackTrace,
            );
            await _handleError(exception);
          },
          onDone: _connectionLost,
          combineWhile: _combineWhile,
        ),
      );

      await _connectionMade();
    } on Exception catch (error) {
      await _handleError(error, connectionFailure: true);
      return;
    }

    _isConnectionSecured = _connecta!.isConnectionSecure;
  }

  Future<void> _handleError(
    dynamic exception, {
    bool connectionFailure = false,
  }) async {
    if (exception is Exception) {
      if (exception is ConnectaException) {
        emit<Object>('connectionFailure', data: exception.message);
      } else {
        emit<Object>('connectionFailure', data: exception);
      }
    }
    if (connectionFailure) {
      emit<TransportState>('state', data: TransportState.connectionFailure);
    }

    if (!(_currentConnectionAttempt?.isCompleted ?? false)) {
      await disconnect(consume: false, sendFooter: false);
      _currentConnectionAttempt = null;
      try {
        _connecta?.destroy();
      } catch (_) {}
      return;
    }

    if (await _reconnectionPolicy.canTriggerFailure()) {
      await _reconnectionPolicy.onFailure();
    } else {
      Log.instance.warning('Reconnection is not set');
    }
  }

  Future<void> _rescheduleConnectionAttempt() async {
    if (_currentConnectionAttempt == null) {
      Log.instance.warning('Current connection attempt is null, aborting...');
      return;
    }

    _currentConnectionAttempt = async.Completer()..complete(_connect());
    return;
  }

  /// Called when the TCP connection has been established with the server.
  Future<void> _connectionMade([bool clearAnswers = false]) async {
    emit<TransportState>('state', data: _eventWhenConnected);
    _currentConnectionAttempt = null;

    sendRaw(streamHeader);

    await _reconnectionPolicy.onSuccess();
    if (clearAnswers) _dnsAnswers = null;
  }

  /// On any kind of disconnection, initiated by us or not. This signals the
  /// closure of connection.
  Future<void> _connectionLost() async {
    Log.instance.warning('Connection lost');

    if (endSessionOnDisconnect) {
      emit('endSession');
      Log.instance.debug('Session ended');
    }
    await disconnect(sendFooter: false);
  }

  /// Performs a handshake for TLS.
  ///
  /// If the handshake is successful, the XML stream will need to be restarted.
  Future<bool> startTLS() async {
    if (_connecta == null) return false;

    if (_disableStartTLS) {
      Log.instance.info('Disable StartTLS is enabled.');
      return false;
    }
    _eventWhenConnected = TransportState.tlsSuccess;
    try {
      await _connecta!.upgradeConnection(
        listener: ConnectaListener(
          onData: _dataReceived,
          onError: (exception, trace) async {
            Log.instance.error(
              'Connection error occured.',
              exception: exception,
              stackTrace: trace as StackTrace,
            );
            await _handleError(exception, connectionFailure: true);
          },
          onDone: _connectionLost,
          combineWhile: _combineWhile,
        ),
      );

      _connectionMade(true);
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

  /// Combines while the given condition is true. Works with [Connecta].
  bool _combineWhile(List<int> bytes) {
    const messageEof = <String>{'</iq>'};
    final data = WhixpUtils.unicode.call(bytes);

    for (final eof in messageEof) {
      if (data.endsWith(eof)) return true;
    }

    return false;
  }

  /// Called when incoming data is received on the socket. We feed that data
  /// to the parser and then see if this produced any XML event. This could
  /// trigger one or more event.
  void _dataReceived(List<int> bytes) {
    final data = WhixpUtils.unicode(bytes);
    _streamController.add(data);
  }

  /// Analyze incoming XML stanzas and convert them into stanza objects if
  /// applicable and queue stream events to be processed by matching handlers.
  Future<void> _spawnEvent(xml.XmlElement element) async {
    final stanza = _buildStanza(element);

    Router.route(stanza);

    Log.instance.debug('RECEIVED: $element');

    /// If the session is started and the upcoming stanza is one of these types,
    /// then increase inbound count for SM.
    if (stanza is IQ || stanza is Message || stanza is Presence) {
      if (_sessionStarted) emit('increaseHandled');
    }
  }

  /// Create a stanza object from a given XML object.
  ///
  /// If a specialized stanza type is not found for the XML, then a generic
  /// [Stanza] stanza will be returned.
  Packet _buildStanza(xml.XmlElement node) =>
      XMLParser.nextPacket(node, namespace: node.getAttribute('xmlns'));

  /// Background [Stream] that processes stanzas to send.
  void _run() => _waitingQueueController.stream.listen((data) async {
        for (final callback in callbacksBeforeStanzaSend) {
          await callback.call(data);
        }
        sendRaw(data.toXMLString());
      });

  /// Forcibly close the connection.
  void abort() {
    if (_connecta != null) {
      _connecta?.destroy();
      emit<TransportState>('state', data: TransportState.killed);
      _cancelConnectionAttempt();
    }
  }

  /// Close the XML stream and wait for ack from the server for at most
  /// [timeout] milliseconds. After the given number of milliseconds have passed
  /// without a response from the server, or when the server successfully
  /// responds with a closure of its own stream, abort() is called.
  Future<void> disconnect({
    int timeout = 2000,
    bool consume = true,
    bool sendFooter = true,
  }) async {
    Log.instance.warning('Disconnect method is called');
    if (sendFooter) sendRaw(streamFooter);

    Future<void> consumeSend() async {
      try {
        await _waitingQueueController.done
            .timeout(Duration(milliseconds: timeout));
      } on Exception {
        /// pass
      } finally {
        _connecta?.destroy();
        _cancelConnectionAttempt();
        emit<TransportState>('state', data: TransportState.disconnected);
      }
    }

    if (_connecta != null && consume) {
      return consumeSend();
    } else {
      emit<TransportState>('state', data: TransportState.disconnected);
      return _connecta?.destroy();
    }
  }

  /// Add a stream event handler that will be executed when a matching stanza
  /// is received.
  void registerHandler(Handler handler) => Router.addHandler(handler);

  /// Removes any transport callback handlers with the given [name].
  void removeHandler(String name) => Router.removeHandler(name);

  /// Triggers a custom [event] manually.
  async.FutureOr<void> emit<T>(String event, {T? data}) async =>
      _eventius.emit<T>(event, data);

  /// Adds a custom [event] handler that will be executed whenever its event is
  /// manually triggered. Works with [Eventius] instance.
  void addEventHandler<B>(
    String event,
    async.FutureOr<void> Function(B? data) listener, {
    bool once = false,
  }) {
    if (once) {
      _eventius.once<B>(event, listener);
    } else {
      _eventius.on<B>(event, listener);
    }
  }

  /// Removes an [event] listeners from the [Eventius] instance according to
  /// provided [handler]. If there is not any [handler] provided, then removes
  /// all the stored handlers.
  void removeEventHandler(String event, {Function? handler}) {
    if (handler == null) {
      _eventius.off(event);
    } else {
      if (_eventius.events[event] != null) {
        _eventius.events[event]!.removeWhere((callback) => callback == handler);
      }
    }
  }

  /// Returns the number [int] of registered handlers for the given [event].
  int eventHandled(String event) {
    if (_eventius.events[event] != null) {
      return _eventius.events[event]!.length;
    } else {
      return 0;
    }
  }

  /// Schedules a callback function to execute after a given delay.
  ///
  /// A unique [name] for the scheduled callback is required.
  /// [seconds] represents the time in seconds to wait before executing.
  /// [repeat] flag indicates if the scheduled event should be reset and repeat
  /// after executing.
  void schedule(
    String name,
    void Function() callback, {
    int seconds = 30,
    bool repeat = false,
  }) {
    if (_scheduledEvents.containsKey(name) && _scheduledEvents[name] != null) {
      return;
    }
    late async.Timer handler;
    if (repeat) {
      handler = async.Timer.periodic(
        Duration(seconds: seconds),
        (_) => callback.call(),
      );
    } else {
      handler = async.Timer(Duration(seconds: seconds), () {
        callback();
        _scheduledEvents.remove(name);
      });
    }
    _scheduledEvents[name] = handler;
  }

  /// Cancels already assigned scheduled callback with the provided [name].
  void cancelSchedule(String name) {
    final handler = _scheduledEvents.remove(name);
    if (handler != null) {
      handler.cancel();
    }
  }

  /// Immediately cancel the current [connect] [Future].
  void _cancelConnectionAttempt() {
    _currentConnectionAttempt = null;
    _connectionTask?.cancel();
    _connecta = null;
    _sessionStarted = false;
  }

  /// Performs any initialization actions, such as handshakes, once the stream
  /// header has been sent.
  ///
  /// Must be overrided.
  late void Function(Map<String, String> attributes) startStreamHandler;

  /// Pick a server and port from DNS answers.
  ///
  /// And also performs DNS resolution for a given hostname.
  ///
  /// Resolution may perform SRV record lookups if a service and protocol are
  /// specified. The returned addresses will be sorted according to the SRV
  /// properties and weights.
  Future<Tuple3<String, String, int>?> _pickDNSAnswer(
    String domain, {
    String? service,
  }) async {
    ResolveResponse? response;
    final srvs = <SRVRecord>[];
    final results = <Tuple3<String, String, int>>[];

    if (service != null) {
      try {
        response = await DNSolve()
            .lookup('_$service._tcp.$domain', type: RecordType.srv)
            .timeout(
          Duration(milliseconds: connectionTimeout),
          onTimeout: () {
            throw async.TimeoutException(
              'Connection timed out',
              Duration(milliseconds: connectionTimeout),
            );
          },
        );
      } catch (_) {
        /// pass
      }
    }

    if (response != null &&
        response.answer != null &&
        (response.answer!.srvs != null && response.answer!.srvs!.isNotEmpty)) {
      for (final record in SRVRecord.sort(response.answer!.srvs!)) {
        if (record.target != null) {
          srvs.add(record);
        }
      }
    }

    if (srvs.isNotEmpty) {
      for (final srv in srvs) {
        if (_useIPv6) {
          final response =
              await DNSolve().lookup(srv.target!, type: RecordType.aaaa);
          if (response.answer != null && response.answer!.records != null) {
            for (final record in response.answer!.records!) {
              results.add(Tuple3(domain, record.name, srv.port));
            }
          }
        }
        final response = await DNSolve().lookup(srv.target!);
        if (response.answer != null) {
          for (final record in response.answer!.records!) {
            results.add(Tuple3(domain, record.name, srv.port));
          }
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

    if (_useIPv6) {
      try {
        response = await DNSolve().lookup(domain, type: RecordType.aaaa);
      } catch (_) {
        Log.instance.warning(
          'DNS lookup: Failed to parse IPv6 records for $domain, processing with provided record',
        );
        return null;
      }
    } else {
      Log.instance.warning('DNS lookup: Use of IPv6 has been disabled');
      try {
        response = await DNSolve().lookup(domain);
      } catch (_) {
        Log.instance.warning(
          'DNS lookup: Failed to parse records for $domain, processing with provided record',
        );
        return null;
      }
    }

    if (response.answer != null && response.answer!.records != null) {
      for (final record in response.answer!.records!) {
        results.add(Tuple3(domain, record.name, _address.secondValue));
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

  Future<void> handleStreamError(
    String otherHost, {
    int maxRedirects = 5,
  }) async {
    if (_redirectAttempts > maxRedirects) {
      return;
    }

    _redirectAttempts++;

    String host = otherHost;
    int port = 5222;

    if (otherHost.contains('[') && otherHost.contains(']')) {
      host = otherHost.split(']').first.substring(1);
    } else if (otherHost.contains(':')) {
      host = otherHost.split(':').first;
    }

    final portsec = otherHost.split(']').last;
    if (portsec.contains(':')) {
      port = int.parse(portsec.split(':')[1]);
    }

    _address = Tuple2(host, port);
    _defaultDomain = host;
    _dnsAnswers = null;
  }

  /// Wraps basic send method declared in this class privately. Helps to send
  /// [Extension] objects.
  void send(Packet data) {
    if (!_sessionStarted) {
      bool passthrough = false;

      if (!passthrough) {
        if (data.name.startsWith('sasl') ||
            data.name.startsWith('sm') ||
            data is IQ) {
          passthrough = true;
        } else {
          switch (data.name) {
            case 'proceed':
              passthrough = true;
            case 'bind':
              passthrough = true;
            case 'session':
              passthrough = true;
            case 'register':
              passthrough = true;
          }
        }
      }

      if (!passthrough) return _queuedStanzas.add(data);
    }

    _waitingQueueController.add(data);
  }

  Future<Packet?> sendAwait<S, F>(
    String handlerName,
    Packet data,
    String successPacket, {
    int timeout = 3,
    String? failurePacket,
  }) async {
    final completer = async.Completer<Packet?>();

    final handler = Handler(
      handlerName,
      (stanza) async {
        if (stanza is S) {
          await Future.microtask(() {
            if (!completer.isCompleted) completer.complete(stanza);
          }).timeout(Duration(seconds: timeout));
          removeHandler(handlerName);
        } else if (stanza is F) {
          await Future.microtask(() {
            if (!completer.isCompleted) completer.complete(null);
          }).timeout(Duration(seconds: timeout));
          removeHandler(handlerName);
        }
      },
    );

    if (failurePacket?.isNotEmpty ?? false) {
      handler.sf(Tuple2(successPacket, failurePacket!));
    } else {
      handler.packet(successPacket);
    }

    registerHandler(handler);

    void callbackTimeout() {
      async.runZonedGuarded(
        () {
          if (!completer.isCompleted) {
            completer.complete(null);
            throw StanzaException.timeout(null);
          }
        },
        (error, trace) => Log.instance.warning(error.toString()),
      );
      removeHandler(handlerName);
    }

    schedule(handlerName, callbackTimeout, seconds: timeout);
    send(data);

    return synchronized(() => completer.future);
  }

  /// Send raw data accross the socket.
  ///
  /// [data] can be either [List] of integers or [String].
  void sendRaw(String data) {
    final raw = WhixpUtils.utf8Encode(data);

    Log.instance.debug('SEND: ${WhixpUtils.unicode(raw)}');

    if (_connecta != null) _connecta?.send(raw);
  }

  /// On session start, queue all pending stanzas to be sent.
  void _setSessionStart() {
    for (final stanza in _queuedStanzas) {
      _waitingQueueController.add(stanza);
    }
    _queuedStanzas.clear();
  }

  /// Host and port keeper. First value refers to host and the second to port.
  Tuple2<String, int> get address => _address;

  /// Indicates whether the connection is established or not.
  bool get isConnected => _connecta != null;

  /// Indicates whether the connection is secured or not.
  bool get isConnectionSecured => _isConnectionSecured;

  /// Indicates that if disable startTLS is activated or not.
  bool get disableStartTLS => _disableStartTLS;
}
