import 'dart:async' as async;
import 'dart:io' as io;

import 'package:dnsolve/dnsolve.dart';
import 'package:synchronized/extension.dart';

import 'package:whixp/src/database/controller.dart';
import 'package:whixp/src/enums.dart';
import 'package:whixp/src/exception.dart';
import 'package:whixp/src/handler/eventius.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/handler/router.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/parser.dart';
import 'package:whixp/src/performance/batcher.dart';
import 'package:whixp/src/performance/metrics.dart';
import 'package:whixp/src/performance/rate_limiter.dart';
import 'package:whixp/src/plugins/features.dart';
import 'package:whixp/src/reconnection.dart';
import 'package:whixp/src/socket/socket_listener.dart';
import 'package:whixp/src/socket/socket_manager.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/message.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/stanza/presence.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/stream.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

part 'connection.dart';

/// Designed to simplify the complexities associated with establishing a
/// connection to a server, as well as sending and receiving XML stanzas.
///
/// Establishes a socket connection, accepts and sends data over this socket.
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
  /// /// it will connect to the "xmpp.is" on port 5223 over DirectTLS
  /// transport.connect();
  /// ```
  Transport(
    /// Hostname that the client needs to establish a connection with
    String host, {
    /// Defaults to 5222
    int port = 5222,

    /// The JabberID (JID) used by this connection, as set after session
    /// binding. This may even be a different bare JID than what was requested
    this.boundJID,

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
    this.pingKeepAlive = true,

    /// The default interval between keepalive signals when [pingKeepAlive] is
    /// enabled. Represents in seconds. Defaults to `180`
    this.pingKeepAliveInterval = 180,

    /// Optional [io.SecurityContext] which is going to be used in socket
    /// connections
    io.SecurityContext? context,

    /// To avoid processing on bad certification you can use this callback.
    ///
    /// Passes [io.X509Certificate] instance when returning boolean value which
    /// indicates to proceed on bad certificate or not.
    bool Function(io.X509Certificate)? onBadCertificateCallback,

    /// Must be declared internal database path.
    String internalDatabasePath = '',

    /// Represents the duration in milliseconds for which the system will wait
    /// for a connection to be established before raising a
    /// [async.TimeoutException].
    ///
    /// Defaults to `2000` milliseconds
    this.connectionTimeout = 2000,

    /// Reconnection strategy if there is an network interruption or disconnect.
    ReconnectionPolicy? reconnectionPolicy,

    /// Enable message batching to reduce network overhead.
    /// When enabled, multiple stanzas are grouped together before sending.
    /// Defaults to `true`.
    bool enableBatching = true,

    /// Maximum number of stanzas to batch before flushing.
    /// Only used when [enableBatching] is `true`.
    /// Defaults to `50`.
    int maxBatchSize = 50,

    /// Maximum time in milliseconds to wait before flushing a batch.
    /// Only used when [enableBatching] is `true`.
    /// Defaults to `100` milliseconds.
    int maxBatchDelay = 100,

    /// Enable rate limiting to prevent overwhelming the server.
    /// Defaults to `true`.
    bool enableRateLimiting = true,

    /// Maximum number of stanzas allowed per second.
    /// Only used when [enableRateLimiting] is `true`.
    /// Defaults to `100` stanzas per second.
    int maxStanzasPerSecond = 100,

    /// Maximum burst size for rate limiting (number of stanzas that can be sent immediately).
    /// Only used when [enableRateLimiting] is `true`.
    /// Defaults to `50`.
    int maxBurst = 50,

    /// Maximum size of the sending queue. When the queue is full, backpressure is applied.
    /// Set to `null` for unbounded queue (not recommended for high-volume applications).
    /// Defaults to `1000`.
    int? maxQueueSize = 1000,
  }) {
    connection = Connection(
      ConnectionConfiguration(
        host: host,
        port: port,
        useTLS: useTLS,
        disableStartTLS: disableStartTLS,
        socketOptions: _SocketListenerImpl(
          onDataCallback: _dataReceived,
          combineWhileCallback: _combineWhile,
          onDoneCallback: _connectionLost,
          onErrorCallback: (exception, trace) => _handleError(exception),
        ),
        securityContext: context,
        connectionTimeout: connectionTimeout,
        useIPv6WhenResolvingDNS: useIPv6,
        service: dnsService,
        onBadCertificateCallback: onBadCertificateCallback,
      ),
      (state) => emit<TransportState>('state', data: state),
      onConnectionStartCallback: () async {
        /// Initialize internal used database for Whixp.
        await _databaseController.initialize();

        /// Reinit XML parser.
        _initParser();

        // Recreate queue controller if it was closed (e.g., on reconnection)
        if (_waitingQueueController.isClosed) {
          _queueSubscription?.cancel();
          _waitingQueueController = async.StreamController<Packet>();
          _run();
        }

        sendRaw(streamHeader);
      },
      handleError: (exception) => _handleError(exception),
    )..initialize(reconnectionPolicy: reconnectionPolicy);

    streamHeader = '<stream>';
    streamFooter = '<stream/>';

    // Initialize performance components
    _rateLimiter = RateLimiter(
      maxStanzasPerSecond: maxStanzasPerSecond,
      maxBurst: maxBurst,
    );
    _rateLimiter.enabled = enableRateLimiting;

    // Initialize metrics
    metrics.reset();

    _batcher = MessageBatcher(
      maxBatchSize: maxBatchSize,
      maxBatchDelay: maxBatchDelay,
      onFlush: (List<Packet> batch) async {
        final startTime = DateTime.now();
        await _flushBatch(batch);
        final flushTime = DateTime.now().difference(startTime);
        metrics.recordBatchFlushed(batch.length, flushTime);
        metrics.updateBatchSize(0); // Reset after flush
      },
    )..setEnabled(enableBatching);

    _maxQueueSize = maxQueueSize;

    // Initialize DatabaseController instance for this Transport
    _databaseController = DatabaseController(
        internalDatabasePath.isEmpty ? null : internalDatabasePath);

    // Initialize queue controller early for seamless data transport
    _waitingQueueController = async.StreamController<Packet>();

    _setup();

    // Start queue processing immediately - it will buffer until connection is ready
    _run();
  }

  /// [Tuple2] type variable that holds both [_host] and [_port].
  late Tuple2<String, int> _address;

  /// The JabberID (JID) used by this connection, as set after session binding.
  ///
  /// This may even be a different bare JID than what was requested.
  JabberID? boundJID;

  /// [Eventius] type variable that holds actual event manager.
  late Eventius _eventius;

  /// Scheduled callback handler [Map] late initializer.
  late Map<String, async.Timer> _scheduledEvents;

  /// If `true`, periodically send a whitespace character over the wire to keep
  /// the connection alive.
  final bool pingKeepAlive;

  /// The default interval between keepalive signals when [pinkKeepAlive] is
  /// enabled.
  final int pingKeepAliveInterval;

  /// Controls if the session can be considered ended if the connection is
  /// terminated.
  bool endSessionOnDisconnect = false;

  /// Default [async.Timer] for [pingKeepAliveInterval]. This will be assigned
  /// when there is a [async.Timer] attached after connection established.
  async.Timer? _keepAliveTimer;

  /// Represents the duration in milliseconds for which the system will wait
  /// for a connection to be established before raising a
  /// [async.TimeoutException].
  final int connectionTimeout;

  late Connection connection;

  /// [async.StreamController] for stanzas to be sent.
  late async.StreamController<Packet> _waitingQueueController;

  /// Stream subscription for processing outgoing stanzas.
  async.StreamSubscription<Packet>? _queueSubscription;

  /// Rate limiter to control outgoing stanza rate
  late RateLimiter _rateLimiter;

  /// Message batcher to group stanzas together
  late MessageBatcher _batcher;

  /// Performance metrics for monitoring client performance.
  final PerformanceMetrics metrics = PerformanceMetrics();

  /// Maximum size of the sending queue (null for unbounded)
  int? _maxQueueSize;

  /// DatabaseController instance for managing database storage for this Transport.
  late final DatabaseController _databaseController;

  /// Gets the DatabaseController instance for this Transport.
  DatabaseController get databaseController => _databaseController;

  /// Gets the DatabaseController instance for this Transport.
  ///
  /// Deprecated: Use [databaseController] instead.
  /// This getter is kept for backward compatibility.
  @Deprecated('Use databaseController instead')
  DatabaseController get hiveController => _databaseController;

  /// [Packet] list of stanzas need to be sent when the connection is
  /// established.
  final _queuedStanzas = <Packet>[];

  /// Actual [StreamParser] instance to manipulate incoming data from the
  /// socket.
  late StreamParser _parser;

  /// [StreamParser] parser should add list of [StreamObject] to this
  /// controller.
  late async.StreamController<String> _streamController;

  /// [StreamParser] parser will communicate with this [async.Stream];
  late async.Stream<List<StreamObject>> _stream;

  /// The default opening tag for the stream element.
  late String streamHeader;

  /// The default closing tag for the stream element.
  late String streamFooter;

  /// Indicates to the default langauge of the last peer.
  String? peerDefaultLanguage;

  /// Current redirect attempt. Increases when there is an attempt occurs to
  /// the redirection (see-other-host).
  late int _redirectAttempts;

  /// Indicates if session is started or not.
  bool _sessionStarted = false;

  /// The list of callbacks that will be triggered before the stanza send.
  final callbacksBeforeStanzaSend =
      <async.FutureOr<void> Function(dynamic data)>[];

  /// Map of pending sendAwait completers that should be cancelled on disconnect
  final Map<String, async.Completer<Packet?>> _pendingAwaitCompleters = {};

  void _setup() {
    _reset();

    addEventHandler<TransportState>('state', (state) {
      if (state == TransportState.disconnected ||
          state == TransportState.killed) {
        if (_keepAliveTimer != null) {
          Log.instance.warning('Stopping Ping keep alive...');
          _keepAliveTimer?.cancel();
        }
        StreamFeatures.supported.clear();

        // Cancel all pending sendAwait requests
        for (final entry in _pendingAwaitCompleters.entries) {
          if (!entry.value.isCompleted) {
            Log.instance.warning(
              'Cancelling pending request: ${entry.key} (connection lost)',
            );
            entry.value.completeError(
              StanzaException.timeout(null, timeoutSeconds: 0),
            );
          }
        }
        _pendingAwaitCompleters.clear();

        _closeStreams();
      }
    });
    addEventHandler('startSession', (_) async {
      _setSessionStart();
      _startKeepAlive();
      _sessionStarted = true;
      await connection.setShouldReconnect(true);
    });
    addEventHandler('endSession', (_) => _sessionStarted = false);
    addEventHandler('streamNegotiated', (_) => _parser.reset());
  }

  void _reset() {
    /// Reset all.
    connection.reset();
    peerDefaultLanguage = null;

    _eventius = Eventius();
    _keepAliveTimer = null;
    _redirectAttempts = 0;
    _scheduledEvents = <String, async.Timer>{};

    // Cancel any pending await completers
    for (final completer in _pendingAwaitCompleters.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          StanzaException.timeout(null, timeoutSeconds: 0),
        );
      }
    }
    _pendingAwaitCompleters.clear();
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
    callbacksBeforeStanzaSend.clear();

    connection.currentConnectionAttempt = async.Completer()
      ..complete(connection.start());
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
          connection.abort(callback: _closeStreams);
        }
      }
    });
  }

  /// Will be set to disconnect method in [Connection]. Responsible to consume
  /// unsent stanzas before disconnection in maximum `5000` milliseconds.
  Future<void> _consumeCallback() =>
      _waitingQueueController.done.timeout(const Duration(milliseconds: 5000));

  Future<void> _handleError(
    dynamic exception, {
    bool connectionFailure = false,
  }) async {
    // Log detailed error information
    if (exception is Exception) {
      if (exception is SocketManagerException) {
        Log.instance.error(
          'Connection error: ${exception.message}',
        );
        emit<Object>('connectionFailure', data: exception.message);
      } else if (exception is AuthenticationException) {
        Log.instance.error(
          'Authentication error: ${exception.message}',
        );
        if (exception.recoverySuggestion != null) {
          Log.instance.info('Recovery: ${exception.recoverySuggestion}');
        }
        emit<Object>('connectionFailure', data: exception);
      } else {
        Log.instance.error(
          'Error: $exception',
        );
        emit<Object>('connectionFailure', data: exception);
      }
    } else {
      Log.instance.error('Unknown error: $exception');
      emit<Object>('connectionFailure', data: exception);
    }

    if (connectionFailure) {
      emit<TransportState>('state', data: TransportState.connectionFailure);
    }

    // Attempt reconnection if policy allows
    if ((await connection._reconnectionPolicy?.canTriggerFailure()) ?? false) {
      Log.instance.info(
        'Reconnection policy triggered. Attempting to reconnect...',
      );
      await connection._reconnectionPolicy?.onFailure();
    } else {
      Log.instance.warning(
        'Reconnection is not configured. Connection will be terminated.',
      );
      await connection.hangup(consume: false, sendFooter: false);
    }
  }

  /// On any kind of disconnection, initiated by us or not. This signals the
  /// closure of connection.
  Future<void> _connectionLost() async {
    Log.instance.warning('Connection is lost');

    if (endSessionOnDisconnect) {
      emit('endSession');
      Log.instance.debug('Session ended');
    }
    await connection.hangup(sendFooter: false);

    /// Close all open sockets when the connection is lost.
    _closeStreams();
  }

  /// Combines while the given condition is true. Works with [SocketManager].
  bool _combineWhile(List<int> bytes) {
    final data = WhixpUtils.unicode.call(bytes);

    // Only attempt to combine IQ stanzas. If the latest IQ stanza isn't yet
    // complete (common when stanzas are split across packets), keep buffering.
    final lastIqStart = data.lastIndexOf('<iq');
    if (lastIqStart == -1) return false;

    final tail = data.substring(lastIqStart);

    // Self-closing IQ: <iq .../>
    final hasSelfClosingIq = RegExp(r'<iq\b[^>]*\/\s*>').hasMatch(tail);
    if (hasSelfClosingIq) return false;

    // Regular IQ: ... </iq> (allow trailing whitespace/newlines)
    final hasIqClose = RegExp(r'</iq\s*>\s*$').hasMatch(tail);
    if (hasIqClose) return false;

    return true;
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
    final parseStart = DateTime.now();
    final stanza = _buildStanza(element);
    final parseTime = DateTime.now().difference(parseStart);
    metrics.recordStanzaReceived();
    metrics.recordStanzaParsed(parseTime);

    Router.route(stanza, this);

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
  void _run() => _queueSubscription = _waitingQueueController.stream.listen(
        (data) async {
          for (final callback in callbacksBeforeStanzaSend) {
            await callback.call(data);
          }
          // Use batcher instead of sending directly
          await _batcher.add(data);
          metrics.updateBatchSize(_batcher.currentBatchSize);
        },
        onError: (error) {
          Log.instance.error('Error in sending queue: $error');
        },
        cancelOnError: false,
      );

  /// Flushes a batch of stanzas, applying rate limiting.
  Future<void> _flushBatch(List<Packet> batch) async {
    for (final packet in batch) {
      // Wait for rate limiter token
      final canSend = await _rateLimiter.canSend();
      if (!canSend) {
        metrics.recordRateLimitHit();
        await _rateLimiter.waitForToken();
      }

      // Send the packet
      sendRaw(packet.toXMLString());
      metrics.recordStanzaSent();
    }
  }

  /// Add a stream event handler that will be executed when a matching stanza
  /// is received.
  void registerHandler(Handler handler) => Router.addHandler(handler);

  /// Removes any transport callback handlers with the given [name].
  void removeHandler(String name) => Router.removeHandler(name);

  /// Triggers a custom [event] manually.
  async.Future<void> emit<T>(String event, {T? data}) =>
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

  /// Performs any initialization actions, such as handshakes, once the stream
  /// header has been sent.
  ///
  /// Must be overrided.
  late void Function(Map<String, String> attributes) startStreamHandler;

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

    connection.reset(host: host, port: port);
  }

  /// Wraps basic send method declared in this class privately. Helps to send
  /// [Extension] objects.
  void send(Packet data) {
    // Before session starts, queue non-critical stanzas for later
    if (!_sessionStarted) {
      // Critical stanzas (IQ, SASL, SM, session establishment) go through immediately
      final isCritical = data is IQ ||
          data.name.startsWith('sasl') ||
          data.name.startsWith('sm') ||
          data.name == 'proceed' ||
          data.name == 'bind' ||
          data.name == 'session' ||
          data.name == 'register';

      if (!isCritical) {
        // Queue non-critical stanzas until session starts
        if (_maxQueueSize != null && _queuedStanzas.length >= _maxQueueSize!) {
          Log.instance.warning(
            'Queue full (${_queuedStanzas.length} >= $_maxQueueSize), dropping packet',
          );
          metrics.recordQueueOverflow();
          return;
        }
        _queuedStanzas.add(data);
        metrics.updateQueueSize(_queuedStanzas.length);
        return;
      }
    }

    // Add to queue (batcher will handle batching and rate limiting)
    if (_waitingQueueController.isClosed) {
      Log.instance.error('Cannot send: queue controller is closed');
      return;
    }

    _waitingQueueController.add(data);
  }

  Future<Packet?> sendAwait<S, F>(
    String handlerName,
    Packet data,
    String successPacket, {
    int timeout = 3,
    String? failurePacket,
  }) {
    final completer = async.Completer<Packet?>();

    // Track this completer so we can cancel it if connection is lost
    _pendingAwaitCompleters[handlerName] = completer;

    final handler = Handler(
      handlerName,
      (stanza) {
        if (stanza is S) {
          if (!completer.isCompleted) {
            _pendingAwaitCompleters.remove(handlerName);
            completer.complete(stanza);
          }
          removeHandler(handlerName);
        } else if (stanza is F) {
          if (!completer.isCompleted) {
            _pendingAwaitCompleters.remove(handlerName);
            completer.complete(null);
          }
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

    schedule(
      handlerName,
      () {
        if (!completer.isCompleted) {
          _pendingAwaitCompleters.remove(handlerName);
          completer.complete(null);
          removeHandler(handlerName);
        }
      },
      seconds: timeout,
    );
    send(data);

    // Clean up completer when future completes (success or error)
    synchronized(() => completer.future)
        .whenComplete(() => _pendingAwaitCompleters.remove(handlerName));

    return synchronized(() => completer.future);
  }

  /// Converts the passed data to raw data and send it using socket.
  void sendRaw(String data) => connection.send(data);

  /// On session start, queue all pending stanzas to be sent.
  void _setSessionStart() {
    for (final stanza in _queuedStanzas) {
      _waitingQueueController.add(stanza);
    }
    _queuedStanzas.clear();
  }

  void _closeStreams() {
    // Cancel queue subscription
    _queueSubscription?.cancel();
    _queueSubscription = null;
    // Flush batcher before closing
    _batcher.dispose();
    _waitingQueueController.close();
    _streamController.close();
  }

  Future<void> disconnect({bool consume = true, bool sendFooter = false}) =>
      connection.hangup(
        consume: consume,
        sendFooter: sendFooter,
        streamFooter: streamFooter,
        consumeCallback: _consumeCallback,
      );

  /// Host and port keeper. First value refers to host and the second to port.
  Tuple2<String, int> get address => _address;

  /// Indicates whether the connection is secured or not.
  bool get isConnectionSecured => connection.isConnectionSecure;
}

/// Implementation of [SocketListener] for [Transport].
class _SocketListenerImpl implements SocketListener {
  _SocketListenerImpl({
    required this.onDataCallback,
    required this.combineWhileCallback,
    required this.onDoneCallback,
    required this.onErrorCallback,
  });

  final void Function(List<int> bytes) onDataCallback;
  final bool Function(List<int> bytes) combineWhileCallback;
  final void Function() onDoneCallback;
  final void Function(Object exception, StackTrace trace) onErrorCallback;

  @override
  void onData(List<int> bytes) => onDataCallback(bytes);

  @override
  bool combineWhile(List<int> bytes) => combineWhileCallback(bytes);

  @override
  void onDone() => onDoneCallback();

  @override
  void onError(Object exception, StackTrace trace) =>
      onErrorCallback(exception, trace);
}
