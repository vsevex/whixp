import 'dart:async' as async;
import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;

import 'package:connecta/connecta.dart';
import 'package:dartz/dartz.dart';
import 'package:dnsolve/dnsolve.dart';

import 'package:echox/src/echotils/src/echotils.dart';
import 'package:echox/src/handler/callback.dart';
import 'package:echox/src/handler/eventius.dart';
import 'package:echox/src/handler/handler.dart';
import 'package:echox/src/jid/jid.dart';
import 'package:echox/src/plugins/bind/stanza.dart';
import 'package:echox/src/stanza/handshake.dart';
import 'package:echox/src/stanza/root.dart';
import 'package:echox/src/stream/base.dart';

import 'package:xml/xml.dart' as xml;
import 'package:xml/xml_events.dart' as parser;

typedef SyncFilter = Function(StanzaBase stanza, [StanzaBase? base]);
typedef AsyncFilter = Future Function(
  StanzaBase stanza, [
  Future<StanzaBase>? callback,
]);

class Transport {
  Transport(
    this._host, {
    int port = 5222,
    this.test = false,
    String? dnsService,
    this.isComponent = false,
    bool useIPv6 = false,
    bool debug = true,
    bool useTLS = false,
    bool disableStartTLS = false,
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
  }

  final String _host;
  late String _serviceName;

  /// Defaults to 5222;
  late int _port;

  late Tuple2<String, int> _address;
  Connecta? _connecta;

  late final Eventius _eventius;
  final bool test;
  late bool _debug;
  late bool _useTLS;
  late bool _disableStartTLS;
  late bool sessionStarted;
  late bool _useIPv6;
  String? _dnsService;

  final _waitingQueue =
      StreamController<Tuple2<Tuple2<StanzaBase?, String?>, bool>>.broadcast();
  late async.Completer<dynamic>? _runOutFilters;
  async.Completer<void>? _currentConnectionAttempt;
  late async.Completer<void> _abortCompleter;
  late bool alwaysSendEverything;
  String? _disconnectReason;
  late int _xmlDepth;

  /// in milliseconds.
  final int? connectionTimeout;
  Iterator<Tuple3<String, String, int>>? _dnsAnswers;
  late String streamHeader;
  void Function(List<parser.XmlEventAttribute> attributes, Transport transport)?
      _startStreamHandlerOverrider;

  final _slowTasks = <Task>[];

  bool isComponent;

  /// The backoff of the connection attempt (increases exponentially after each
  /// failure). Represented in milliseconds;
  late int _connectFutureWait;

  late String _eventWhenConnected;

  late List<Tuple2<String, String?>> _caCerts;

  String _defaultDomain = '';
  late String defaultNamespace;

  late bool _isConnectionSecured;
  String? peerDefaultLanguage;

  late final List<Handler> _handlers;
  final _rootStanza = <StanzaBase>[];

  late bool sessionBind;

  /// The JabberID (JID) used by this connection, as set after session binding.
  ///
  /// This may even be a different bare JID than what was requested.
  JabberIDTemp boundJID;

  late bool _startStreamHandlerCalled;

  final _filters = <String, List<Tuple2<SyncFilter?, AsyncFilter?>>>{};

  void _setup() {
    _reset();

    final setDisconnectedListener =
        _eventius.createListener<dynamic>('disconnected', (_) {
      _setDisconnected();
    });

    _eventius.addEvent(setDisconnectedListener);
  }

  void _reset() {
    _serviceName = '';
    _address = Tuple2(_host, _port);

    _eventius = Eventius();

    sessionStarted = false;
    _startStreamHandlerCalled = false;

    _runOutFilters = null;
    _abortCompleter = async.Completer<void>();

    _connectFutureWait = 0;
    _xmlDepth = 0;
    _eventWhenConnected = 'connected';

    alwaysSendEverything = false;
    defaultNamespace = '';
    peerDefaultLanguage = null;

    _handlers = <Handler>[];
    _rootStanza.clear();

    sessionBind = false;

    _filters
      ..clear()
      ..addAll({
        'in': <Tuple2<SyncFilter, AsyncFilter>>[],
        'out': <Tuple2<SyncFilter, AsyncFilter>>[],
        'outSync': <Tuple2<SyncFilter, AsyncFilter>>[],
      });
    _slowTasks.clear();
    _connecta = null;
  }

  void connect() {
    if (_runOutFilters == null || _runOutFilters!.isCompleted) {
      _runOutFilters ??= async.Completer<dynamic>();
      _runOutFilters!.complete(runFilters());
    }

    _disconnectReason = null;
    _cancelConnectionAttempt();
    _connectFutureWait = 0;

    _defaultDomain = _address.value1;

    emit('connecting');
    _currentConnectionAttempt = async.Completer()..complete(_connect());
  }

  Future<void> _connect() async {
    _eventWhenConnected = 'connected';

    if (_connectFutureWait > 0) {
      emit<int>('reconnectDelay', data: _connectFutureWait);
      await Future.delayed(Duration(milliseconds: _connectFutureWait));
    }
    final record =
        await _pickDNSAnswer(_defaultDomain, service: _dnsService, test: test);

    if (record != null) {
      final host = record.value1;
      final address = record.value2.substring(0, record.value2.length - 1);
      final port = record.value3;

      _address = Tuple2(address, port);
      _serviceName = host;
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
      await _connecta!.connect(
        ConnectaListener(
          onData: _dataReceived,
          onError: (error, trace) => print(error),
        ),
      );

      _connectionMade();
    } on ConnectaException catch (error) {
      emit<Object>('connectionFailed', data: error.message);
      _rescheduleConnectionAttempt();
    } on Exception catch (error) {
      print(error);
      emit<Object>('connectionFailed', data: error);
      _rescheduleConnectionAttempt();
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
      } else if (_xmlDepth == 1) {
        final index = data.indexOf('<${event.name}');
        final element = xml.XmlDocument.parse(data.substring(index, event.stop))
            .rootElement;
        if (element.getAttribute('xmlns') == null) {
          element.setAttribute('xmlns', Echotils.getNamespace('JABBER_STREAM'));
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
    final stanza = _buildStanza(
      element,
      defaultNamespace: Echotils.getNamespace('JABBER_STREAM'),
    );

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
      stanza.unhandled();
    }
  }

  StanzaBase _buildStanza(xml.XmlElement element, {String? defaultNamespace}) {
    final namespace = defaultNamespace ?? this.defaultNamespace;

    StanzaBase stanzaClass = StanzaBase();

    String tag() =>
        '<${element.localName} xmlns="${element.getAttribute('xmlns')}"/>';

    for (final stanza in _rootStanza) {
      if ((element.localName == stanza.name &&
              element.getAttribute('xmlns') == namespace) ||
          tag() == stanza.tag) {
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
    for (final filter
        in _filters['out'] ?? <Tuple2<SyncFilter?, AsyncFilter?>>[]) {
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
    _waitingQueue.stream.listen((data) {
      if (data.value1.value1 != null) {
        if (data.value2) {
          final alreadyRunFilters = <Tuple2<SyncFilter?, AsyncFilter?>>{};
          for (final filter
              in _filters['out'] ?? <Tuple2<SyncFilter?, AsyncFilter?>>[]) {
            alreadyRunFilters.add(filter);
            if (filter.value2 != null) {
              final task =
                  Task(() => filter.value2!.call(data.value1 as StanzaBase));
              try {
                // data = await task.timeout(const Duration(seconds: 1)).run();

                // Handle the completed value
              } on async.TimeoutException {
                // Handle the case where the timeout occurred
                print('Timeout occurred and add to slow tasks');

                _slowSend(task, alreadyRunFilters);
              }
            } else if (data.value1 is StanzaBase) {
              filter.value1!.call(data.value1 as StanzaBase);
            }
          }
        }
      }
      if (data.value1.value1 != null) {
        if (data.value2) {
          for (final filter in _filters['outSync']!) {
            filter.value1!.call(data.value1 as StanzaBase);
          }
        }
        late String rawData;
        if (data.value1.value1 != null) {
          rawData = data.value1.value1.toString();
        } else {
          rawData = data.value1.value2!;
        }
        sendRaw(rawData);
      } else if (data.value1.value2 != null) {
        sendRaw(data);
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
        emit('killed');
      }
    }
  }

  void reconnect() {
    print('reconnecting..');
    Future<void> handler(String? event) async {
      await Future.delayed(Duration.zero);
      connect();
    }

    final listener =
        _eventius.createListener('disconnected', handler, disposable: true);
    _eventius.addEvent(listener);
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
  void emit<T>(String event, {T? data}) {
    print('event triggered: $event');

    _eventius.emit<T>(event, data);
  }

  void _cancelConnectionAttempt() {
    _currentConnectionAttempt = null;
    _connecta = null;
  }

  void _rescheduleConnectionAttempt() {
    if (_currentConnectionAttempt == null) {
      return;
    }
    _connectFutureWait = math.min(300, _connectFutureWait * 2 + 100);
    _currentConnectionAttempt = async.Completer()..complete(_connect());
  }

  /// Performs any initialization actions, such as handshakes, once the stream
  /// header has been sent.
  void _startStreamHandler(List<parser.XmlEventAttribute> attributes) =>
      _startStreamHandlerOverrider?.call(attributes, this);

  Future<Tuple3<String, String, int>?> _pickDNSAnswer(
    String domain, {
    bool test = false,
    String? service,
  }) async {
    print('use of useIPv6  has been disabled');
    if (test || domain == 'localhost') {
      print(
        'because of test flag is true and this is used to be tested locally, do not look for dns records',
      );

      return Tuple3(domain, domain, _port);
    }
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

  /// Wraps basic send method declared in this class privately. Helps to send
  /// stanza objects.
  void send(Tuple2<StanzaBase?, String?> data, {bool useFilters = true}) {
    if (!alwaysSendEverything && !sessionStarted) {
      bool passthrough = false;
      if (data.value1 != null && data.value1 is Handshake) {
        passthrough = true;
      }

      if (data is Tuple2<RootStanza?, String?> && !passthrough) {
        print('not sent: $data');
      }
    }
    _waitingQueue.add(Tuple2(data, useFilters));
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
  // void _setSessionStart() {
  //   sessionStarted = true;
  //   for (final stanza in _queuedStanzas.activeItems) {
  //     _waitingQueue.add(() => stanza);
  //   }
  // }

  void _setDisconnected() => sessionStarted = false;

  Tuple2<String, int> get address => _address;

  bool get isConnected => _connecta != null;

  bool get isConnectionSecured => _isConnectionSecured;

  bool get disableStartTLS => _disableStartTLS;
}
