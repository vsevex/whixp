import 'dart:async' as async;
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:connecta/connecta.dart';
import 'package:dartz/dartz.dart';
import 'package:dnsolve/dnsolve.dart';
import 'package:meta/meta.dart';

import 'package:whixp/src/handler/eventius.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/stanza/handshake.dart';
import 'package:whixp/src/stanza/root.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/utils/utils.dart';
import 'package:whixp/src/whixp.dart';

import 'package:xml/xml.dart' as xml;
import 'package:xml/xml_events.dart' as parser;

/// Filterization types of incoming and outgoing stanzas.
enum FilterMode { iN, out, outSync }

/// A synchronous filter function for processing [StanzaBase] objects.
///
/// This filter is a typedef representing a function that takes a [StanzaBase]
/// object as input, processes it synchronously, and returns a modified or
/// processed [StanzaBase].
///
/// It is typically used for applying synchronous transformations or filters to
/// stanza objects.
@internal
typedef SyncFilter = StanzaBase Function(StanzaBase stanza);

/// An asynchronous filter function for processing [StanzaBase] objects.
///
/// An AsyncFilter is a typedef representing a function that takes a
/// [StanzaBase] object as input, processes it asynchronously, and returns a
/// modified or processed [StanzaBase] wrapped in [Future].
@internal
typedef AsyncFilter = Future<StanzaBase> Function(StanzaBase stanza);

/// Designed to simplify the complexities associated with establishing a
/// connection to as server, as well as sending and receiving XML "stanzas".
///
/// The class manages two streams, each responsible for communication in a
/// specific direction over the same socket.
class Transport {
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
  /// transport.connect();  /// this will connect to the "xmpp.is" on port 5223 over DirectTLS
  /// ```
  Transport(
    /// The hostname that the client needs to establish a connection with
    this._host, {
    /// Defaults to 5222
    int port = 5222,

    /// The JabberID (JID) used by this connection, as set after session
    /// binding. This may even be a different bare JID than what was requested
    required this.boundJID,

    /// The service name to check with DNS SRV records. For example, setting this
    /// to "xmpp-client" would query the "_xmpp-clilent._tcp" service.
    String? dnsService,

    /// The distinction between clients and components can be important, primarily
    /// for choosing how to handle the `to` and `from` [JabberID]s of stanzas
    this.isComponent = false,

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

    /// Controls if the session can be considered ended if the connection is
    /// terminated.
    bool endSessionOnDisconnect = true,

    /// If `true`, periodically send a whitespace character over the wire to
    /// keep the connection alive
    this.whitespaceKeepAlive = true,

    /// The default interval between keepalive signals when [whitespaceKeepAlive]
    /// is enabled. Represents in seconds. Defaults to `300`
    this.whitespaceKeepAliveInterval = 300,

    /// The maximum number of reconnection attempts that the [Transport] will
    /// make in case the connection with the server is lost or cannot be
    /// established initially. Defaults to 3
    this.maxReconnectionAttempt = 3,

    /// [List] of paths to a file containing certificates for verifying the
    /// server TLS certificate. Uses [Tuple2], the first side is for path to the
    /// cert file and the second to the password file
    Map<String, String?>? caCerts,

    /// To avoid processing on bad certification you can use this callback.
    ///
    /// Passes [io.X509Certificate] instance when returning boolean value which
    /// indicates to proceed on bad certificate or not.
    bool Function(io.X509Certificate)? onBadCertificateCallback,

    /// Represents the duration in milliseconds for which the system will wait
    /// for a connection to be established before raising a [TimeoutException].
    ///
    /// Defaults to 2000 milliseconds
    this.connectionTimeout = 2000,

    /// The overrider for the function of [startStreamHandler].
    ///
    /// Performs any initialization actions, such as handshakes, once the stream
    /// header has been sent
    void Function(
      List<parser.XmlEventAttribute> attributes,
      Transport transport,
    )? startStreamHandler,
  }) {
    _port = port;

    _useTLS = useTLS;
    _disableStartTLS = disableStartTLS;
    _useIPv6 = useIPv6;
    _dnsService = dnsService;

    _endSessionOnDisconnect = endSessionOnDisconnect;

    streamHeader = '<stream>';
    streamFooter = '<stream/>';

    _caCerts = caCerts ?? <String, String?>{};

    _startStreamHandlerOverrider = startStreamHandler;
    _onBadCertificateCallback = onBadCertificateCallback;

    _setup();
  }

  /// The host that [Whixp] has to connect to.
  final String _host;

  /// The port that [Whixp] has to connect to.
  late int _port;

  /// [Tuple2] type variable that holds both [_host] and [_port].
  late Tuple2<String, int> _address;

  /// The JabberID (JID) used by this connection, as set after session binding.
  ///
  /// This may even be a different bare JID than what was requested.
  late JabberID boundJID;

  /// Will hold host that [Whixp] is connected to and will work in the
  /// association of [SASL].
  late String serviceName;

  /// The distinction between clients and components can be important, primarily
  /// for choosing how to handle the `to` and `from` [JabberID]s of stanzas.
  bool isComponent;

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

  /// Flag that indicates to if the session has been started or not.
  late bool sessionStarted;

  /// If set to `true`, attempt to use IPv6.
  late bool _useIPv6;

  /// If `true`, periodically send a whitespace character over the wire to keep
  /// the connection alive.
  final bool whitespaceKeepAlive;

  /// Controls if the session can be considered ended if the connection is
  /// terminated.
  late final bool _endSessionOnDisconnect;

  /// The default interval between keepalive signals when [whitespaceKeepAlive]
  /// is enabled.
  final int whitespaceKeepAliveInterval;

  /// Default [Timer] for [whitespaceKeepAliveInterval]. This will be assigned
  /// when there is a [Timer] attached after connection established.
  async.Timer? _whitespaceKeepAliveTimer;

  /// The service name to check with DNS SRV records. For example, setting this
  /// to "xmpp-client" would query the "_xmpp-clilent._tcp" service.
  String? _dnsService;

  /// Represents the duration in milliseconds for which the system will wait
  /// for a connection to be established before raising a [TimeoutException].
  final int connectionTimeout;

  /// The maximum number of reconnection attempts that the [Transport] will
  /// make in case the connection with the server is lost or cannot be
  /// established initially. Defaults to 3.
  late int maxReconnectionAttempt;

  /// [List] of paths to a file containing certificates for verifying the
  /// server TLS certificate. Uses [Tuple2], the first side is for path to the
  /// cert file and the second to the password file.
  late Map<String, String?> _caCerts;

  /// [StreamController] for [_waitingQueue].
  final _waitingQueueController =
      async.StreamController<Tuple2<StanzaBase, bool>>.broadcast();
  final _queuedStanzas = <Tuple2<StanzaBase, bool>>[];

  late async.Completer<dynamic>? _runOutFilters;

  /// [Completer] of current connection attempt. After the connection, this
  /// [Completer] should be equal to null.
  async.Completer<void>? _currentConnectionAttempt;

  /// Current connection attempt count. It works with [maxReconnectionAttempt].
  int _currentConnectionAttemptCount = 0;

  /// This variable is used to keep track of stream header and footer. If stream
  /// is opened without closing that, it will keep its state at "1". When there
  /// is a closing tag, that means it should be equal to zero and close the
  /// connection.
  late int _xmlDepth;

  /// [Iterator] of DNS results that have not yet been tried.
  Iterator<Tuple3<String, String, int>>? _dnsAnswers;

  /// The default opening tag for the stream element.
  late String streamHeader;

  /// The default closing tag for the stream element.
  late String streamFooter;

  /// The overrider for the function of [startStreamHandler].
  ///
  /// Performs any initialization actions, such as handshakes, once the stream
  /// header has been sent.
  void Function(List<parser.XmlEventAttribute> attributes, Transport transport)?
      _startStreamHandlerOverrider;

  /// [Task] [List] to keep track of [Task]s that are going to be sent slowly.
  final _slowTasks = <Task>[];

  /// [io.ConnectionTask] keeps current connection task and can be used to
  /// cancel if there is a need.
  io.ConnectionTask<io.Socket>? _connectionTask;

  /// The backoff of the connection attempt (increases exponentially after each
  /// failure). Represented in milliseconds;
  late int _connectFutureWait;

  /// The event to trigger when the [_connect] succeeds. It can be "connected"
  /// or "tlsSuccess" depending on the step we are at.
  late String _eventWhenConnected;

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

  /// List of [Handler]s.
  final _handlers = <Handler>[];

  /// List of [StanzaBase] stanzas that incoming stanzas can built from.
  final _rootStanza = <StanzaBase>[];

  /// Indicates session bind.
  late bool sessionBind;

  /// Used when wrapping incoming xml stream.
  late bool _startStreamHandlerCalled;

  /// To avoid processing on bad certification you can use this callback.
  ///
  /// Passes [io.X509Certificate] instance when returning boolean value which
  /// indicates to proceed on bad certificate or not.
  bool Function(io.X509Certificate)? _onBadCertificateCallback;

  /// Current redirect attempt. Increases when there is an attempt occurs to
  /// the redirection (see-other-host).
  late int _redirectAttempts;

  /// [Map] to keep "in", "out", and "outSync" type filters to use when there
  /// is a need for stanza filtering.
  final _filters = <FilterMode, List<Tuple2<SyncFilter?, AsyncFilter?>>>{};

  /// The reason why whixp disconnects from the server.
  String? _disconnectReason;

  void _setup() {
    _reset();

    addEventHandler<String>('disconnected', (_) {
      if (_whitespaceKeepAliveTimer != null) {
        _whitespaceKeepAliveTimer!.cancel();
      }
      _setDisconnected();
    });
    addEventHandler('sessionStart', (_) {
      _setSessionStart();
      _startKeepAlive();
    });
  }

  void _reset() {
    serviceName = '';
    _address = Tuple2(_host, _port);

    _eventius = Eventius();

    sessionBind = false;
    sessionStarted = false;
    _startStreamHandlerCalled = false;

    _runOutFilters = null;

    _whitespaceKeepAliveTimer = null;

    _eventWhenConnected = 'connected';
    _redirectAttempts = 0;
    _connectFutureWait = 0;
    _xmlDepth = 0;

    defaultNamespace = '';

    _handlers.clear();
    _rootStanza.clear();
    _slowTasks.clear();

    defaultLanguage = null;
    peerDefaultLanguage = null;

    _filters
      ..clear()
      ..addAll({
        FilterMode.iN: <Tuple2<SyncFilter?, AsyncFilter?>>[],
        FilterMode.out: <Tuple2<SyncFilter?, AsyncFilter?>>[],
        FilterMode.outSync: <Tuple2<SyncFilter?, AsyncFilter?>>[],
      });

    _connecta = null;
    _connectionTask = null;

    _scheduledEvents = <String, async.Timer>{};
  }

  /// Begin sending whitespace periodically to keep the connection alive.
  void _startKeepAlive() {
    if (whitespaceKeepAlive) {
      _whitespaceKeepAliveTimer = async.Timer.periodic(
        Duration(seconds: whitespaceKeepAliveInterval),
        (_) => sendRaw(''),
      );
    }
  }

  /// Creates a new socket and connect to the server.
  ///
  /// The parameters needed to establish a connection in order are passed
  /// beforehand when creating [Transport] instance.
  @internal
  void connect() {
    if (_runOutFilters == null || _runOutFilters!.isCompleted) {
      _runOutFilters = async.Completer<dynamic>()..complete(runFilters());
    }

    _disconnectReason = null;
    _cancelConnectionAttempt();
    _connectFutureWait = 0;

    _defaultDomain = _address.value1;

    emit('connecting');
    _currentConnectionAttempt = async.Completer()..complete(_connect());
  }

  Future<void> _connect() async {
    _currentConnectionAttemptCount++;
    _eventWhenConnected = 'connected';

    if (_connectFutureWait > 0) {
      await Future.delayed(Duration(seconds: _connectFutureWait));
    }
    final record = await _pickDNSAnswer(_defaultDomain, service: _dnsService);

    if (record != null) {
      final host = record.value1;
      final address = record.value2.substring(0, record.value2.length - 1);
      final port = record.value3;

      _address = Tuple2(address, port);
      serviceName = host;
    } else {
      _dnsAnswers = null;
    }

    io.SecurityContext? context;

    if (_caCerts.isNotEmpty) {
      io.SecurityContext? context = io.SecurityContext(withTrustedRoots: true);
      for (final caCert in _caCerts.entries) {
        try {
          context!.setTrustedCertificates(
            caCert.key,
            password: caCert.value,
          );
        } on Exception {
          context = null;
        }
      }
    }

    if (_useTLS) {
      _connecta = Connecta(
        ConnectaToolkit(
          hostname: _address.value1,
          port: _address.value2,
          timeout: connectionTimeout,
          connectionType: ConnectionType.tls,
          onBadCertificateCallback: _onBadCertificateCallback,
          context: context,
        ),
      );
    } else {
      _connecta = Connecta(
        ConnectaToolkit(
          hostname: _address.value1,
          port: _address.value2,
          timeout: connectionTimeout,
          context: _disableStartTLS ? null : context,
          onBadCertificateCallback: _onBadCertificateCallback,
          connectionType: _disableStartTLS
              ? ConnectionType.tcp
              : ConnectionType.upgradableTcp,
        ),
      );
    }

    try {
      Log.instance.info(
        'Trying to connect to ${_address.value1} on port ${_address.value2}',
      );

      _connectionTask = await _connecta!.createTask(
        ConnectaListener(
          onData: _dataReceived,
          onError: (error, trace) async {
            Log.instance.error(
              'Connection error',
              error: error,
              stackTrace: trace as StackTrace,
            );
            final result = _rescheduleConnectionAttempt();
            if (!result) {
              await disconnect(consume: false);
            }
          },
          onDone: _connectionLost,
        ),
      );

      _connectionMade();
    } on ConnectaException catch (error) {
      emit<Object>('connectionFailed', data: error.message);
      final result = _rescheduleConnectionAttempt();
      if (!result) {
        await disconnect(consume: false);
      }
    } on Exception catch (error) {
      emit<Object>('connectionFailed', data: error);
      final result = _rescheduleConnectionAttempt();
      if (!result) {
        await disconnect(consume: false);
      }
    }

    _isConnectionSecured = _connecta!.isConnectionSecure;
  }

  /// Called when the TCP connection has been established with the server.
  void _connectionMade([bool clearAnswers = false]) {
    emit(_eventWhenConnected);
    _currentConnectionAttempt = null;
    sendRaw(streamHeader);
    _initParser();
    if (clearAnswers) {
      _dnsAnswers = null;
    }
  }

  /// On any kind of disconnection, initiated by us or not. This signals the
  /// closure of connection.
  void _connectionLost() {
    Log.instance.info('Connection lost.');
    _connecta = null;

    if (_endSessionOnDisconnect) {
      emit('sessionEnd');
      Log.instance.debug('Cancelling slow send tasks.');
      for (final task in _slowTasks) {
        task.voided;
      }
      _slowTasks.clear();
    }
    _setDisconnected();
    emit<String>('disconnected', data: _disconnectReason);
  }

  /// Performs a handshake for TLS.
  ///
  /// If the handshake is successful, the XML stream will need to be restarted.
  @internal
  Future<bool> startTLS() async {
    if (_connecta == null) return false;
    if (_disableStartTLS) {
      Log.instance.info('Disable StartTLS is enabled');
      return false;
    }
    _eventWhenConnected = 'tlsSuccess';
    try {
      await _connecta!.upgradeConnection(
        listener: ConnectaListener(
          onData: _dataReceived,
          onError: (error, trace) => Log.instance.error(
            'Connection error',
            error: error,
            stackTrace: trace as StackTrace,
          ),
          onDone: _connectionLost,
        ),
      );

      _connectionMade(true);
      return true;
    } on ConnectaException catch (error) {
      Log.instance.error(error.message);
      if (_dnsAnswers != null && _dnsAnswers!.moveNext()) {
        startTLS();
      } else {
        rethrow;
      }
      return false;
    }
  }

  /// Called when incoming data is received on the socket. We feed that data
  /// to the parser and then see if this produced any XML event. This could
  /// trigger one or more event.
  Future<void> _dataReceived(List<int> bytes) async {
    bool wrapped = false;
    String data = WhixpUtils.unicode(bytes);
    if (data.contains('<stream:stream') && !data.contains('</stream:stream>')) {
      data = _streamWrapper(data);
      wrapped = true;
    }

    void onStartElement(parser.XmlStartElementEvent event) {
      if (event.isSelfClosing ||
          (event.name == 'stream:stream' && _startStreamHandlerCalled)) return;
      if (_xmlDepth == 0) {
        /// We have received the start of the root element.
        Log.instance.info('RECEIVED: $data');
        _disconnectReason = 'End of the stream';
        _startStreamHandler(event.attributes);
        _startStreamHandlerCalled = true;
      }
      _xmlDepth++;
    }

    Future<void> onEndElement(parser.XmlEndElementEvent event) async {
      if (event.name == 'stream:stream' && wrapped) return;
      _xmlDepth--;
      if (_xmlDepth == 0) {
        /// The stream's root element has closed, terminating the stream.
        Log.instance.info('End of stream received');
        abort();
        return;
      } else if (_xmlDepth == 1) {
        int index = data.lastIndexOf('<${event.name}');
        if (index > event.stop!) {
          index = data.indexOf('<${event.name}');
        }
        final substring = data.substring(index, event.stop);
        if (substring.isEmpty) return;
        final element = xml.XmlDocument.parse(substring).rootElement;
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
      }
    }

    Stream.value(data)
        .toXmlEvents(withLocation: true, withParent: true)
        .normalizeEvents()
        .tapEachEvent(
          onStartElement: onStartElement,
          onEndElement: onEndElement,
        )
        .listen((events) async {
      if (events.length == 1) {
        final event = events.first;
        if (event is parser.XmlStartElementEvent &&
            event.name == 'stream:stream') {
          abort();
          return;
        } else if (event is parser.XmlEndElementEvent &&
            event.name == 'stream:stream') {
          abort();
          return;
        }
      }
      if (events.length == 1) {
        final element = xml.XmlDocument.parse(data).rootElement;
        await _spawnEvent(element);
      }
    });
  }

  /// Helper method to wrap the incoming stanza in order not to get parser
  /// error.
  String _streamWrapper(String data) {
    if (data.contains('<stream:stream')) {
      return '$data</stream:stream>';
    }
    return data;
  }

  /// Analyze incoming XML stanzas and convert them into stanza objects if
  /// applicable and queue steram events to be processed by matching handlers.
  Future<void> _spawnEvent(xml.XmlElement element) async {
    final stanza = _buildStanza(element);

    bool handled = false;
    final handlers = <Handler>[];
    for (final handler in _handlers) {
      if (handler.match(stanza)) {
        handlers.add(handler);
      }
    }

    Log.instance.debug('RECEIVED: $element');

    for (final handler in handlers) {
      try {
        await handler.run(stanza);
      } on Exception catch (excp) {
        stanza.exception(excp);
      }
      handled = true;
    }

    if (!handled) {
      stanza.unhandled(this);
    }
  }

  /// Create a stanza object from a given XML object.
  ///
  /// If a specialized stanza type is not found for the XML, then a generic
  /// [StanzaBase] stanza will be returned.
  StanzaBase _buildStanza(xml.XmlElement element) {
    StanzaBase stanzaClass = StanzaBase(element: element, receive: true);

    final tag = '{${element.getAttribute('xmlns')}}${element.localName}';

    for (final stanza in _rootStanza) {
      if (tag == stanza.tag) {
        stanzaClass = stanza.copy(element: element, receive: true);
        break;
      }
    }
    if (stanzaClass['lang'] == null && peerDefaultLanguage != null) {
      stanzaClass['lang'] = peerDefaultLanguage;
    }
    return stanzaClass;
  }

  Future<void> _slowSend(
    Task task,
    Set<Tuple2<SyncFilter?, AsyncFilter?>> alreadyUsed,
  ) async {
    final completer = async.Completer<dynamic>();
    completer.complete(task.run());

    final data = await completer.future;
    _slowTasks.remove(task);
    if (data == null && !completer.isCompleted) {
      return;
    }
    for (final filter in _filters[FilterMode.out]!) {
      if (alreadyUsed.contains(filter)) {
        continue;
      }
      if (filter.value2 != null) {
        completer.complete(filter.value2!.call(data as StanzaBase));
      } else {
        completer.complete(filter.value1?.call(data as StanzaBase));
      }
      if (data == null) {
        return;
      }
    }
  }

  /// Background [Stream] that processes stanzas to send.
  @internal
  Future<void> runFilters() async {
    _waitingQueueController.stream.listen((data) async {
      StanzaBase datum = data.value1;
      final useFilters = data.value2;
      if (useFilters) {
        final alreadyRunFilters = <Tuple2<SyncFilter?, AsyncFilter?>>{};
        for (final filter in _filters[FilterMode.out]!) {
          alreadyRunFilters.add(filter);
          if (filter.value2 != null) {
            final task = Task(() => filter.value2!.call(data.value1));
            try {
              datum = await task.timeout(const Duration(seconds: 1)).run();
            } on async.TimeoutException {
              /// Handle the case where the timeout occurred
              Log.instance.error('Slow Future, rescheduling filters');

              _slowSend(task, alreadyRunFilters);
            }
          } else {
            datum = filter.value1!.call(datum);
          }
        }
      }

      if (useFilters) {
        for (final filter in _filters[FilterMode.outSync]!) {
          filter.value1!.call(datum);
        }

        final rawData = datum.toString();

        sendRaw(rawData);
      }
    });
  }

  /// Init the XML parser. The parser must always be reset for each new
  /// connection.
  void _initParser() {
    _xmlDepth = 0;
    _startStreamHandlerCalled = false;
  }

  /// Forcibly close the connection.
  void abort() {
    if (_connecta != null) {
      _connecta!.destroy();
      emit('killed');
      _cancelConnectionAttempt();
    }
  }

  /// Calls disconnect(), and once we are disconnected (after the timeout, or
  /// when the server ack is received), call connect().
  void reconnect() {
    Log.instance.info('Reconnecting...');
    Future<void> handler(String? data) async {
      await Future.delayed(Duration.zero);
      connect();
    }

    _eventius.once<String>('disconnected', handler);
    disconnect();
  }

  /// Close the XML stream and wait for ack from the server for at most
  /// [timeout] milliseconds. After the given number of milliseconds have passed
  /// without a response from the server, or when the server successfully
  /// responds with a closure of its own stream, abort() is called.
  Future<void> disconnect({
    String? reason,
    int timeout = 2000,
    bool consume = true,
  }) async {
    Log.instance.warning('Disconnect is called');

    /// Run abort() if we do not received the disconnected event after a
    /// waiting time.
    ///
    /// Timeout defaults to 2000 milliseconds.
    Future<void> endStreamWait() async {
      try {
        sendRaw(streamFooter);
        await _waitUntil('disconnected', timeout: timeout);
      } on async.TimeoutException {
        abort();
      }
    }

    Future<void> consumeSend() async {
      try {
        await _waitingQueueController.done
            .timeout(Duration(milliseconds: timeout));
      } on async.TimeoutException {
        /// pass;
      }
      _disconnectReason = reason;
      await endStreamWait();
    }

    if (_connecta != null && consume) {
      _disconnectReason = reason;
      await consumeSend();

      return _cancelConnectionAttempt();
    } else {
      emit<String>('disconnected', data: reason);
      return;
    }
  }

  /// Utility method to wake on the next firing of an event.
  Future<dynamic> _waitUntil(String event, {int timeout = 15000}) async {
    final completer = async.Completer<dynamic>();

    void handler(String? data) {
      if (completer.isCompleted) {
        Log.instance
            .debug('Completer registered on event "$event" is already done');
      } else {
        completer.complete(data);
      }
    }

    addEventHandler<String>(event, handler, once: true);

    return completer.future.timeout(Duration(milliseconds: timeout));
  }

  /// Adds a stanza class as a known root stanza.
  ///
  /// A root stanza is one that appears as a direct child of the stream's root
  /// element.
  ///
  /// Stanzas that appear as substanzas of a root stanza do not need to be
  /// registered here. That is done using [registerPluginStanza] from [XMLBase].
  void registerStanza(StanzaBase stanza) => _rootStanza.add(stanza);

  /// Removes a stanza from being a known root stanza.
  ///
  /// A root stanza is one that appears as a direct child of the stream's root
  /// element.
  ///
  /// Stanzas that are not registered will not be converted into stanza objects,
  /// but may still be processed using handlers and matchers.
  void removeStanza(StanzaBase stanza) => _rootStanza.remove(stanza);

  /// Add a stream event handler that will be executed when a matching stanza
  /// is received.
  void registerHandler(Handler handler) {
    if (handler.transport == null) {
      handler.transport = this;
      _handlers.add(handler);
    }
  }

  /// Removes any transport callback handlers with the given [name].
  bool removeHandler(String name) {
    for (final handler in _handlers) {
      if (handler.name == name) {
        _handlers.remove(handler);
        return true;
      }
    }
    return false;
  }

  /// Triggers a custom [event] manually.
  void emit<T extends Object>(String event, {T? data}) =>
      _eventius.emit<T>(event, data);

  /// Add a custom [event] handler that will be executed whenever its event is
  /// manually triggered. Works with [Eventius] instance.
  @internal
  void addEventHandler<B extends Object>(
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
      handler = async.Timer.periodic(Duration(seconds: seconds), (_) {
        callback();
        _scheduledEvents.remove(name);
      });
    } else {
      handler = async.Timer(Duration(seconds: seconds), () {
        callback();
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
    if (_connectionTask != null) {
      _connectionTask!.cancel();
    }
    _currentConnectionAttemptCount = 0;
    _connecta = null;
  }

  bool _rescheduleConnectionAttempt() {
    if (_currentConnectionAttempt == null ||
        (maxReconnectionAttempt <= _currentConnectionAttemptCount)) {
      return false;
    }
    _connectFutureWait = math.min(300, _connectFutureWait * 2 + 1);
    _currentConnectionAttempt = async.Completer()..complete(_connect());
    return true;
  }

  /// Performs any initialization actions, such as handshakes, once the stream
  /// header has been sent.
  void _startStreamHandler(List<parser.XmlEventAttribute> attributes) =>
      _startStreamHandlerOverrider?.call(attributes, this);

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
    Log.instance.warning('DNS: Use of IPv6 has been disabled');

    ResolveResponse? response;
    final srvs = <SRVRecord>[];
    final results = <Tuple3<String, String, int>>[];

    if (service != null) {
      response = await DNSolve()
          .lookup('_$service._tcp.$domain', type: RecordType.srv)
          .timeout(Duration(milliseconds: connectionTimeout));
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
      response = await DNSolve().lookup(domain, type: RecordType.aaaa);
    } else {
      response = await DNSolve().lookup(domain);
    }

    if (response.answer != null && response.answer!.records != null) {
      for (final record in response.answer!.records!) {
        results.add(
          Tuple3(domain, record.name, _address.value2),
        );
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

  @internal
  void handleStreamError(String otherHost, {int maxRedirects = 5}) {
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
    reconnect();
  }

  /// Add a filter for incoming or outgoing stnzas.
  ///
  /// These filters are applied before incoming stanzas are passed to any
  /// handlers, and before outgoing stanzas are put in the send queue.
  ///
  /// [mode] can be "iN", "out", and "outSync". Either sync or async filter
  /// can be passed at the same time. You can not assign two type filters once.
  void addFilter<T>({
    FilterMode mode = FilterMode.iN,
    SyncFilter? filter,
    AsyncFilter? asyncFilter,
  }) {
    if (filter != null) {
      _filters[mode]!.add(Tuple2(filter, null));
    } else if (asyncFilter != null) {
      _filters[mode]!.add(Tuple2(null, asyncFilter));
    }
  }

  /// Wraps basic send method declared in this class privately. Helps to send
  /// [StanzaBase] objects.
  void send(StanzaBase data, {bool useFilters = true}) {
    if (!sessionStarted) {
      bool passthrough = false;

      if (data is RootStanza && !passthrough) {
        if (data.getPlugin('bind', check: true) != null) {
          passthrough = true;
        } else if (data.getPlugin('session', check: true) != null) {
          passthrough = true;
        }
      } else if (data is Handshake) {
        passthrough = true;
      }

      if (data is RootStanza && !passthrough) {
        _queuedStanzas.add(Tuple2(data, useFilters));
        return;
      }
    }
    _waitingQueueController.add(Tuple2(data, useFilters));
  }

  /// Send raw data accross the socket.
  ///
  /// [data] can be either [List] of integers or [String].
  void sendRaw(dynamic data) {
    String rawData;
    if (data is List<int>) {
      rawData = WhixpUtils.unicode(data);
    } else if (data is String) {
      rawData = data;
    } else {
      throw ArgumentError(
        'Passed data to be sent is neither List<int> nor String',
      );
    }
    Log.instance.debug('SEND: $rawData');

    if (_connecta != null) {
      _connecta!.send(rawData);
    }
  }

  /// On session start, queue all pending stanzas to be sent.
  void _setSessionStart() {
    sessionStarted = true;
    for (final stanza in _queuedStanzas) {
      _waitingQueueController.add(stanza);
    }
    _queuedStanzas.clear();
  }

  void _setDisconnected() => sessionStarted = false;

  /// Host and port keeper. First value refers to host and the second to port.
  Tuple2<String, int> get address => _address;

  /// Indicates whether the connection is established or not.
  bool get isConnected => _connecta != null;

  /// Indicates whether the connection is secured or not.
  bool get isConnectionSecured => _isConnectionSecured;

  /// Indicates that if disable startTLS is activated or not.
  bool get disableStartTLS => _disableStartTLS;
}
