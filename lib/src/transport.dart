import 'dart:async' as async;
import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:connecta/connecta.dart';
import 'package:dartz/dartz.dart';
import 'package:dnsolve/dnsolve.dart';

import 'package:echox/src/echotils/src/echotils.dart';
import 'package:echox/src/handler/eventius.dart';
import 'package:echox/src/handler/handler.dart';
import 'package:echox/src/jid/jid.dart';
import 'package:echox/src/stanza/handshake.dart';
import 'package:echox/src/stream/base.dart';
import 'package:echox/src/whixp.dart';

import 'package:meta/meta.dart';

import 'package:xml/xml.dart' as xml;
import 'package:xml/xml_events.dart' as parser;

enum FilterMode { iN, out, outSync }

typedef SyncFilter = StanzaBase Function(StanzaBase stanza);
typedef AsyncFilter = Future<StanzaBase> Function(StanzaBase stanza);

class Transport {
  Transport(
    this._host, {
    int port = 5222,
    String? dnsService,
    this.isComponent = false,
    bool useIPv6 = false,
    bool debug = true,
    bool useTLS = false,
    bool disableStartTLS = false,
    this.maxReconnectionAttempt = 3,
    required this.boundJID,
    List<Tuple2<String, String?>>? caCerts,
    this.connectionTimeout,
    void Function(
      List<parser.XmlEventAttribute> attributes,
      Transport transport,
    )? startStreamHandler,
  }) {
    _port = port;

    _setup();

    _debug = debug;
    _useTLS = useTLS;
    _disableStartTLS = disableStartTLS;
    _useIPv6 = useIPv6;
    _dnsService = dnsService;

    streamHeader = '<stream>';

    _caCerts = caCerts ?? [];

    _startStreamHandlerOverrider = startStreamHandler;

    addEventHandler('sessionStart', <_>([_]) => _setSessionStart());
  }

  late final String _host;
  late String serviceName;

  /// Defaults to 5222;
  late int _port;

  late Tuple2<String, int> _address;
  Connecta? _connecta;

  late final Eventius _eventius;
  late bool _debug;
  late bool _useTLS;
  late bool _disableStartTLS;
  late bool sessionStarted;
  late bool _useIPv6;
  String? _dnsService;

  late final Stream<Tuple2<StanzaBase, bool>> _waitingQueue;
  final _waitingQueueController =
      StreamController<Tuple2<StanzaBase, bool>>.broadcast();
  final _queuedStanzas = <Tuple2<StanzaBase, bool>>[];
  late async.Completer<dynamic>? _runOutFilters;
  async.Completer<void>? _currentConnectionAttempt;
  int _currentConnectionAttemptCount = 0;
  late async.Completer<void> _abortCompleter;
  late int _xmlDepth;

  /// in milliseconds.
  late final int? connectionTimeout;
  Iterator<Tuple3<String, String, int>>? _dnsAnswers;
  late String streamHeader;
  late String streamFooter;
  void Function(List<parser.XmlEventAttribute> attributes, Transport transport)?
      _startStreamHandlerOverrider;

  final _slowTasks = <Task>[];

  bool isComponent = false;

  /// The backoff of the connection attempt (increases exponentially after each
  /// failure). Represented in milliseconds;
  late int _connectFutureWait;

  late String _eventWhenConnected;

  late List<Tuple2<String, String?>> _caCerts;

  String _defaultDomain = '';
  late String defaultNamespace;

  late bool _isConnectionSecured;
  String? defaultLanguage;
  String? peerDefaultLanguage;

  late final List<Handler> _handlers;
  final _rootStanza = <StanzaBase>[];

  late bool sessionBind;

  /// The JabberID (JID) used by this connection, as set after session binding.
  ///
  /// This may even be a different bare JID than what was requested.
  late JabberID boundJID;

  late bool _startStreamHandlerCalled;
  late int maxReconnectionAttempt;

  late int _redirectAttempts;

  io.ConnectionTask<io.Socket>? _connectionTask;

  final _filters = <FilterMode, List<Tuple2<SyncFilter?, AsyncFilter?>>>{};

  void _setup() {
    _reset();

    _eventius.on('disconnected', (_) => _setDisconnected());
  }

  void _reset() {
    serviceName = '';
    _address = Tuple2(_host, _port);

    _eventius = Eventius();

    sessionStarted = false;
    _startStreamHandlerCalled = false;

    _runOutFilters = null;
    _abortCompleter = async.Completer<void>();

    _connectFutureWait = 0;
    _xmlDepth = 0;
    _eventWhenConnected = 'connected';

    defaultNamespace = '';
    peerDefaultLanguage = null;

    _handlers = <Handler>[];
    _rootStanza.clear();
    defaultLanguage = null;

    sessionBind = false;

    _filters
      ..clear()
      ..addAll({
        FilterMode.iN: <Tuple2<SyncFilter?, AsyncFilter?>>[],
        FilterMode.out: <Tuple2<SyncFilter?, AsyncFilter?>>[],
        FilterMode.outSync: <Tuple2<SyncFilter?, AsyncFilter?>>[],
      });

    _slowTasks.clear();
    _connecta = null;
    _connectionTask = null;

    _waitingQueue = _waitingQueueController.stream;
    _redirectAttempts = 0;
  }

  void connect() {
    if (_runOutFilters == null || _runOutFilters!.isCompleted) {
      _runOutFilters ??= async.Completer<dynamic>();
      _runOutFilters!.complete(runFilters());
    }

    _cancelConnectionAttempt();
    _connectFutureWait = 0;

    _defaultDomain = _address.value1;

    emit('connecting');
    _currentConnectionAttempt = async.Completer()..complete(_connect());
  }

  Future<void> _connect() async {
    _eventWhenConnected = 'connected';

    if (_connectFutureWait > 0) {
      await Future.delayed(Duration(milliseconds: _connectFutureWait));
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
      context = io.SecurityContext(withTrustedRoots: true);
      for (final caCert in _caCerts) {
        context.setTrustedCertificates(
          caCert.value1,
          password: caCert.value2,
        );
      }
    }

    if (_useTLS) {
      _connecta = Connecta(
        ConnectaToolkit(
          hostname: _address.value1,
          port: _address.value2,
          connectionType: ConnectionType.tls,
          onBadCertificateCallback: (cert) => true,
          context: context,
        ),
      );
    } else {
      _connecta = Connecta(
        ConnectaToolkit(
          hostname: _address.value1,
          port: _address.value2,
          context: _disableStartTLS ? null : context,
          connectionType: _disableStartTLS
              ? ConnectionType.tcp
              : ConnectionType.upgradableTcp,
        ),
      );
    }

    try {
      print(
        'trying to connect to ${_address.value1} on port ${_address.value2}',
      );
      _connectionTask = await _connecta!.createTask(
        ConnectaListener(
          onData: _dataReceived,
          onError: (error, trace) => print(error),
        ),
      );

      _connectionMade();
    } on ConnectaException catch (error) {
      emit<Object>('connectionFailed', data: error.message);
      final result = _rescheduleConnectionAttempt();
      if (!result) {
        await disconnect();
      }
    } on Exception catch (error) {
      emit<Object>('connectionFailed', data: error);
      final result = _rescheduleConnectionAttempt();
      if (!result) {
        await disconnect();
      }
    }

    _isConnectionSecured = _connecta!.isConnectionSecure;
  }

  void _connectionMade([bool clearAnswers = false]) {
    emit(_eventWhenConnected);
    _currentConnectionAttempt = null;
    sendRaw(streamHeader);
    _initParser();
    if (clearAnswers) {
      _dnsAnswers = null;
    }
  }

  Future<bool> startTLS() async {
    if (_connecta == null) return false;
    if (_disableStartTLS) {
      print('disable start TLS is true');
      return false;
    }
    _eventWhenConnected = 'tlsSuccess';
    try {
      await _connecta!.upgradeConnection(
        listener: ConnectaListener(
          onData: _dataReceived,
          onError: (error, trace) => print(error),
        ),
      );

      _connectionMade(true);
      return true;
    } on ConnectaException {
      if (_dnsAnswers != null && _dnsAnswers!.moveNext()) {
        startTLS();
      } else {
        rethrow;
      }
      return false;
    }
  }

  Future<void> _dataReceived(List<int> bytes) async {
    bool wrapped = false;
    String data = Echotils.unicode(bytes);
    if (data.contains('<stream:stream') && !data.contains('</stream:stream>')) {
      data = _streamWrapper(data);
      wrapped = true;
    }

    print('data received: $data');
    void onStartElement(parser.XmlStartElementEvent event) {
      if (event.isSelfClosing ||
          (event.name == 'stream:stream' && _startStreamHandlerCalled)) return;
      if (_xmlDepth == 0) {
        _startStreamHandler(event.attributes);
        _startStreamHandlerCalled = true;
      }
      _xmlDepth++;
    }

    Future<void> onEndElement(parser.XmlEndElementEvent event) async {
      if (event.name == 'stream:stream' && wrapped) return;
      _xmlDepth--;
      if (_xmlDepth == 0) {
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
          if (element.qualifiedName == 'message') {
            element.setAttribute('xmlns', Echotils.getNamespace('CLIENT'));
          } else {
            element.setAttribute(
              'xmlns',
              Echotils.getNamespace('JABBER_STREAM'),
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

  String _streamWrapper(String data) {
    if (data.contains('<stream:stream')) {
      return '$data</stream:stream>';
    }
    return data;
  }

  Future<void> _spawnEvent(xml.XmlElement element) async {
    final stanza = _buildStanza(element);

    bool handled = false;
    final handlers = <Handler>[];
    for (final handler in _handlers) {
      if (handler.match(stanza)) {
        handlers.add(handler);
      }
    }

    for (final handler in handlers) {
      print('Handler ${handler.name} ran...');
      try {
        await handler.run(stanza);
      } on Exception catch (excp) {
        print(excp);

        /// TODO: catch callback exceptions in here.
        stanza.exception(excp);
      }
      handled = true;
    }

    if (!handled) {
      stanza.unhandled(this);
    }
  }

  StanzaBase _buildStanza(xml.XmlElement element) {
    StanzaBase stanzaClass = StanzaBase(element: element, receive: true);

    String tag() =>
        '<${element.localName} xmlns="${element.getAttribute('xmlns')}"/>';

    for (final stanza in _rootStanza) {
      if (tag() == stanza.tag) {
        stanzaClass = stanza.copy(element, null, true);
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
              // Handle the case where the timeout occurred
              print('Timeout occurred and add to slow tasks');

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
      _abortCompleter.complete(_connecta!.socket.flush());
      if (_abortCompleter.isCompleted) {
        _cancelConnectionAttempt();
        _connecta = null;
        emit('killed');
      }
    }
  }

  void reconnect() {
    print('reconnecting..');
    Future<void> handler(String? data) async {
      await Future.delayed(Duration.zero);
      connect();
    }

    _eventius.once<String>('disconnected', handler);
  }

  Future<void> disconnect({String? reason, int timeout = 15000}) async {
    print('disconnect is called');

    Future<void> endStreamWait() async {
      try {
        sendRaw(streamFooter);
        await _waitUntil('disconnected', timeout: timeout);
      } on TimeoutException {
        abort();
      }
    }

    Future<void> consumeSend() async {
      await Future.delayed(Duration(milliseconds: timeout));
      await endStreamWait();
    }

    if (_connecta != null) {
      if (await _waitingQueue.isEmpty) {
        _cancelConnectionAttempt();
        return endStreamWait();
      } else {
        return consumeSend();
      }
    } else {
      emit<String>('disconnected', data: reason);
      return;
    }
  }

  Future<void> _waitUntil(String event, {int timeout = 15000}) async {
    final completer = Completer();

    void handler(dynamic data) {
      completer.complete(data);
    }

    addEventHandler(event, handler, once: true);

    return completer.future.timeout(Duration(milliseconds: timeout));
  }

  void registerStanza(StanzaBase stanza) {
    print('registering stanza: $stanza');
    _rootStanza.add(stanza);
  }

  void registerHandler(Handler handler) {
    print('registered handler: ${handler.name}');
    if (handler.transport == null) {
      handler.transport = this;
      _handlers.add(handler);
    }
  }

  /// Triggers a custom [event] manually.
  void emit<T>(String event, {T? data}) => _eventius.emit<T>(event, data);

  void addEventHandler<B>(
    String event,
    FutureOr<void> Function(B? data) listener, {
    bool once = false,
  }) {
    if (once) {
      _eventius.once<B>(event, listener);
    } else {
      _eventius.on<B>(event, listener);
    }
  }

  void _cancelConnectionAttempt() {
    _currentConnectionAttempt = null;
    if (_connectionTask != null) {
      _connectionTask!.cancel();
    }
    _currentConnectionAttemptCount = 0;
    _connecta = null;
  }

  bool _rescheduleConnectionAttempt() {
    _currentConnectionAttemptCount++;

    if (_currentConnectionAttempt == null ||
        (maxReconnectionAttempt < _currentConnectionAttemptCount)) {
      return false;
    }
    _connectFutureWait = math.min(300, _connectFutureWait * 2 + 100);
    _currentConnectionAttempt = async.Completer()..complete(_connect());
    return true;
  }

  /// Performs any initialization actions, such as handshakes, once the stream
  /// header has been sent.
  void _startStreamHandler(List<parser.XmlEventAttribute> attributes) =>
      _startStreamHandlerOverrider?.call(attributes, this);

  Future<Tuple3<String, String, int>?> _pickDNSAnswer(
    String domain, {
    String? service,
  }) async {
    print('use of useIPv6  has been disabled');

    ResolveResponse? response;
    final srvs = <SRVRecord>[];
    final results = <Tuple3<String, String, int>>[];

    if (service != null) {
      response = await DNSolve()
          .lookup('_$service._tcp.$domain', type: RecordType.srv);
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
          Tuple3(domain, record.name, _port),
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

  void handleStreamError(String otherHost, {int maxRedirects = 5}) {
    if (_redirectAttempts > maxRedirects) {
      return;
    }

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
  /// stanza objects.
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

  void sendRaw(dynamic data) {
    String rawData;
    if (data is List<int>) {
      rawData = Echotils.unicode(data);
    } else if (data is String) {
      rawData = data;
    } else {
      throw ArgumentError(
        'passed data to be sent is neither List<int> nor String',
      );
    }
    if (_connecta != null) {
      print('send: $data');
      _connecta!.send(rawData);
    } else {
      /// TODO: throw not connected error
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

  Tuple2<String, int> get address => _address;

  bool get isConnected => _connecta != null;

  bool get isConnectionSecured => _isConnectionSecured;

  bool get disableStartTLS => _disableStartTLS;
}

@visibleForTesting
Transport testTransport({
  String jid = 'vsevex@localhost',
  String password = 'tester13',
  String host = 'example.com',
  int port = 5222,
  bool useTLS = true,
}) {
  final client = Whixp(
    jid,
    password,
    host: 'localhost',
    port: port,
    useTLS: useTLS,
  );

  client.transport.sessionBind = true;

  client.transport.defaultLanguage = null;
  client.transport.peerDefaultLanguage = null;

  client.transport._dataReceived(
    Echotils.stringToArrayBuffer(client.transport.streamHeader),
  );

  return client.transport;
}

@visibleForTesting
Future<void> receive(String data, Transport transport) async {
  await Future.delayed(const Duration(seconds: 1));
  await transport._dataReceived(Echotils.stringToArrayBuffer(data));
}
