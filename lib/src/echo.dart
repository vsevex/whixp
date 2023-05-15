import 'dart:async';
import 'dart:math' as math;

import 'package:echo/src/builder.dart';
import 'package:echo/src/constants.dart';
import 'package:echo/src/log.dart';
import 'package:echo/src/protocol.dart';
import 'package:echo/src/sasl.dart';
import 'package:echo/src/sasl_anon.dart';
import 'package:echo/src/sasl_external.dart';
import 'package:echo/src/sasl_oauthbearer.dart';
import 'package:echo/src/sasl_plain.dart';
import 'package:echo/src/sasl_sha1.dart';
import 'package:echo/src/sasl_sha256.dart';
import 'package:echo/src/sasl_sha384.dart';
import 'package:echo/src/sasl_sha512.dart';
import 'package:echo/src/sasl_xoauth2.dart';
import 'package:echo/src/utils.dart';
import 'package:echo/src/websocket.dart';

import 'package:xml/xml.dart' as xml;

class Echo {
  Echo({
    required this.service,
    this.options = const <String, dynamic>{},
  }) {
    setProtocol();

    /// The connected JID
    jid = '';

    /// The JIDs domain
    domain = null;

    /// stream:features
    features = null;

    /// SASL
    saslData = {};

    mechanisms = {};

    protocolErrorHandlers = {
      // 'HTTP': {},
      'websocket': {},
    };

    doAuthentication = false;
    paused = false;

    maxRetries = 5;

    _connectionPlugins = {};

    /// Initialize the start point.
    reset();

    /// Call onIdle callback every 1/10th of a second.
    _idleTimeout =
        Timer.periodic(const Duration(milliseconds: 100), (_) => _onIdle);
    _disconnectTimeout = null;
    registerMechanisms();

    /// TODO: implement plugin initialization method in this scope.
  }

  /// The service URL
  String service;

  /// Configuration options
  final Map<String, dynamic> options;

  /// Handles an error by logging it as a fatal error.
  ///
  /// The [e] parameter represents the error object, which can be of any type.
  /// It is recommended to pass an instance of [Exception] or a subclass of it
  /// for meaningful error messages.
  ///
  /// The error is logged using the `fatal` level of the [Log] class.
  ///
  /// ### Example usage:
  /// ```dart
  /// try {
  ///   // code that may throw an error
  /// } catch (e) {
  ///   _handleError(e);
  /// }
  /// ```
  ///
  /// Throws:
  ///   - A runtime exception if the [Log] class is not available or properly
  /// configured.
  ///
  /// See also:
  ///   - [Log.fatal] method in the [Log] class for logging fatal errors.
  ///
  static void _handleError(dynamic e) {
    Log().fatal(e.toString());
  }

  Protocol? protocol;
  int? _uniqueId;
  int? maxRetries;
  int? disconnectionTimeout;
  _TimedHandler? _disconnectTimeout;
  String? jid;
  String? domain;
  String? authcid;
  String? authzid;
  // Handler? iqFallbackHandler;
  Map<String, dynamic>? features;
  dynamic password;
  Map<String, dynamic>? saslData;
  Map<String, SASL>? mechanisms;

  /// [Map] used to store protocol error handlers. It is structured as a nested
  /// map, where the outer map is indexed by the protocol name (e.g. `HTTP`),
  /// and the inner map is indexed by the status code associated with the error.
  ///
  /// Each status code is mapped to a callback function that will be invoked
  /// when the corresponding error occurs.
  Map<String, Map<int, Function>>? protocolErrorHandlers;
  Map<String, dynamic>? _connectionPlugins;
  bool? authenticated;
  bool? connected;
  bool? disconnecting;
  bool? doAuthentication = true;
  bool? paused;
  bool? restored;
  bool? doBind;
  bool? doSession;
  List? data;
  List? _requests;
  List? scramKeys;

  /// This variable appears to be a list used to store instances of the
  /// [_Handler] class, representing XMPP stanza handlers.
  List<_Handler>? addHandlers;

  /// This variable appears to be alist used to store instance of the
  /// [_Handler] class which is meant to be removed.
  List<_Handler>? removeHandlers;
  List<Function>? timedHandlers;
  List<_Handler>? handlers;

  /// This variable appears to be a list used to store references to timed
  /// handlers that should be removed.
  List<_TimedHandler>? removeTimeds;

  /// The addTimeds variable appears to be a list that holds instances of
  /// [_TimedHandler] objects. It is used to store and manage timed handlers
  /// that have been added using the `addTimedHandler` method
  List<_TimedHandler>? addTimeds;
  Timer? _idleTimeout;

  /// This variable represents a function that can be assigned to handle the
  /// connection status and related data after a connection attempt.
  Function(Status, [String?, xml.XmlElement?])? connectCallback;
  _Handler? _saslSuccessHandler;
  Function? _saslFailureHandler;
  Function? _saslChallengeHandler;

  /// `version` constant
  static const version = '0.0.1';

  /// Select protocol based on `options` or `service`.
  void setProtocol() {
    final protocol = options['protocol'] ?? '';
    if (options['worker'] != null && options['worker'] as bool) {
    } else if (service.startsWith('ws:') ||
        service.startsWith('wss:') ||
        (protocol as String).startsWith('ws')) {
      this.protocol = Websocket(this);
    }
  }

  void addConnectionPlugin(String name, dynamic pluginType) {
    _connectionPlugins![name] = pluginType;
  }

  void reset() {
    protocol!.reset();
    doSession = false;
    doBind = false;

    /// handler lists
    timedHandlers = [];
    handlers = [];
    removeTimeds = [];
    removeHandlers = [];
    addTimeds = [];
    addHandlers = [];

    data = [];
    _requests = [];
    _uniqueId = 0;

    authenticated = false;
    connected = false;
    disconnecting = false;
    restored = false;
  }

  /// Pause the request manager.
  ///
  /// This will prevent [Echo] from sending any more requests to the server.
  /// This is very useful for temporarily pausing BOSH-Connections (in our case,
  /// we will stop accepting something from WebSockets) while a lot of send()
  /// calls are happening quickly.
  ///
  /// This causes [Echo] to send the data in a single request, saving many
  /// request trips.
  void pause() => paused = true;

  /// Resume the request manager.
  ///
  /// This resumes after `pause()` has been called.
  void resume() => paused = false;

  /// Responsibility of this method is generating a unique ID for use in <iq />
  /// stanzas.
  ///
  /// All <iq /> stanzas are required to have unique id attributes. This
  /// function makes creating this ease. Each connection instance has a counter
  /// which starts from zero, and the value of this counter plus a colon
  /// followed by the suffix becomes the unique id. If no suffix is supplied,
  /// the counter is used as the unique id.
  ///
  /// * @param suffix A optional suffix to append to the unique id.
  /// * @return The generated unique ID.
  String getUniqueId(dynamic suffix) {
    /// It follows the format specified by the UUID version 4 standart.
    final uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
        .replaceAllMapped(RegExp('[xy]'), (match) {
      final r = math.Random.secure().nextInt(16);
      final v = match.group(0) == 'x' ? r : (r & 0x3 | 0x8);
      return v.toRadixString(16);
    });

    /// Check whether the provided suffix is [String] or [int], so if type is
    /// one of them, proceed to concatting.
    if (suffix is String || suffix is num) {
      return '$uuid:$suffix';
    } else {
      return uuid;
    }
  }

  /// NOTE: Actually, this method does not have any meaning at the moment due the
  /// [Echo] only supports messaging through Websockets, so if there will be
  /// any improvement on the BOSH request in the future, this method can be
  /// used for handling HTTP errors.
  ///
  /// The responsibility is to register handler function for when a protocol
  /// error occurs (FOR NOW ONLY HTTP).
  ///
  /// * @param protocol HTTP
  /// * @param statusCode Error status code (e.g. 500, 400, or 404)
  /// * @param callback Function that will fire HTTP error
  ///
  /// ### Example usage
  /// ```dart
  /// final connection = Echo('http://example.com/http-bind');
  /// connection.addProtocolErrorHandler('HTTP', 500, onError);
  /// /// Triggers HTTP 500 error and onError handler will be called.
  /// connection.connect('jid@incorrect_jabber', 'secret', onConnect);
  /// ```
  void addProtocolErrorHandler(
    /// Dedicated protocol for handling errors. For now only can accept `HTTP`.
    String protocol,

    /// Status code of the error.
    int statusCode,

    /// The callback that will be executed when the error occured.
    void Function() callback,
  ) =>
      protocolErrorHandlers![protocol]![statusCode] = callback;

  /// The main function of this class.
  ///
  /// Starts the connection process.
  ///
  /// As the connection process proceeds, the user supplied callback will be
  /// triggered multiple times with the status updates. The callback should take
  /// two arguments - the status code and the error condition.
  ///
  /// The status will be one of the values in [Status] enums. The error
  /// condition will be one of the conditions defined in RFC 3920 or the
  /// condition `strope-parsererror`.
  ///
  /// * @param jid - The user's JID. This may be a bare JID, or a full JID. If
  /// a node supplied, `SASL OAUTHBEARER` or `SASL ANONYMOUS` authentication
  /// will be attempted (OAUTHBEARER will process the provided password value
  /// as an access token.)
  /// * @param password The user's password, or an object containing the users
  /// SCRAM client and server keys, in a fashion described as follows:
  /// ```dart
  /// {
  ///   'name': /// String, representation the has used (e.g. SHA-1),
  ///   'salt': /// String, base64 encoded salt used to derive the client key,
  ///   'iter': /// int, the iteration count used to derive the client key,
  ///   'ck': /// String, the base64 encoding of the SCRAM client key,
  ///   'sk': /// String, the base64 encoding of the SCRAM server key
  /// }
  /// ```
  /// * @param callback The connect callback function.
  /// * @param authcid The optional alternative authentication identity
  /// (username) if intending to impersonate another user.
  /// When using the SASL-EXTERNAL authentication mechanism, for example with
  /// client certifictes, then the authcid value is used to determine whehter
  /// an authorization JID (authzid) should be sent to the server.
  /// The `authzid` should NOT be sent to the server if the `authzid` and
  /// `authcid` are the same. So to prevent it from being sent, set `authcid`
  /// to that same JID. See XEP-178 for more details.
  /// * @param disconnectionTimeout The optional disconnection timeout in
  /// milliseconds before `doDisconnect` will be called.
  void connect({
    /// User's Jabber identifier.
    required String jid,

    /// The user's password.
    dynamic password,

    /// The connection callback function.
    void Function(Status)? callback,

    /// Optional alternative authentication identifier.
    String? authcid,

    /// Disconnection timeout before terminating.
    int disconnectionTimeout = 3000,
  }) {
    /// Equal gathered `jid` to global one.
    this.jid = jid;

    /// Authorization identity (username)
    authzid = Utils().getBareJIDFromJID(jid);

    /// Authentication identity. Equal gathered `password` to global password.
    this.password = password;

    /// The SASL SCRAM client and server keys. This variable will be populated
    /// with a non-null object of the above described form after a successful
    /// SCRAM connection.
    scramKeys = null;

    /// Connection callback will be equal if there is one.
    connectCallback = (status, [condition, element]) => callback!.call(status);

    /// Restore all initial values for connection.
    disconnecting = false;
    connected = false;
    authenticated = false;
    restored = false;

    /// Make global `disconnectionTimeout` value to be equal to passed one.
    this.disconnectionTimeout = disconnectionTimeout;

    /// Parse `jid` for domain.
    domain = Utils().getDomainFromJID(jid);

    /// Change the status of connection to `connecting`.
    changeConnectStatus(Status.connecting, null);

    /// Build connection of the `protocol`.
    protocol!.connect();
  }

  /// Helper function that makes sure plugins and the user's callback are
  /// notified of connection status changes.
  ///
  /// * @param status New connection status, one of the values of [Status] enum.
  /// * @param condition The error condition or null.
  /// * @param element The triggering stanza.
  void changeConnectStatus(
    /// Status of the connection.
    Status status,

    /// Error condition map value.
    String? condition,

    /// [xml.XmlElement] type element parameter.
    [
    xml.XmlElement? element,
  ]) {
    // for (final k in _connectionPlugins!.keys) {
    //   final plugin = _connectionPlugins![k];
    //   if (plugin!.status != status) {
    //     try {
    //       plugin.status = status;
    //     } catch (error) {
    //       Log().error('$k plugin caused an exception changing status: $error');
    //     }
    //   }
    // }
    if (connectCallback != null) {
      try {
        connectCallback!.call(status, condition, element);
      } catch (error) {
        _handleError(error);
        Log().error('User connection callback caused an exception: $error');
      }
    }
  }

  /// Attach to an already created an authenticated BOSH session.
  // void attach(
  //   String jid,
  //   String sid,
  //   String rid,
  //   void Function() callback,
  // ) {}

  /// Attempt to restore a cached BOSH session.
  // void restore() {}

  /// User overrideable function that receives XML data coming into the
  /// connection.
  ///
  /// The default function does nothing. User code can override this with:
  /// ```dart
  /// echo.xlmInput = (element) {
  ///   /// ...user code
  /// }
  /// ```
  ///
  /// * @param element The XML data received by the connection.
  void xmlInput(dynamic element) {}

  /// User overrideable function that receives XML data sent to the connection.
  ///
  /// The default function does nothing. User code can override this with:
  /// ```dart
  /// echo.xmlOutput = (element) {
  ///   /// ...user code
  /// }
  /// ```
  /// * @param element The XMLdata sent by the connection.
  void xmlOutput(dynamic element) {
    return;
  }

  /// User overrideable function that receives raw data coming into the
  /// connection.
  ///
  /// The default function does nothing. User can override this with:
  /// ```dart
  /// echo.rawInput = (data) {
  ///   /// ...user code
  /// }
  /// ```
  /// * @param data The data received by the connection.
  void rawInput(dynamic data) {
    return;
  }

  /// User overrideable function that receives raw data sent to the connection.
  ///
  /// The default function does nothing. User code can override this with:
  /// ```dart
  /// echo.rawOutput = (data) {
  ///   /// ...user code
  /// }
  /// ```
  void rawOutput(dynamic data) {
    return;
  }

  /// User overrideable function that receives the new valid rid.
  ///
  /// The default function does nothing. User can override this with:
  /// ```dart
  /// echo.nextValidRid = (rid) {
  ///   /// ...user code
  /// }
  /// ```
  /// * @param rid The next valid rid
  void nextValidRid(num rid) {
    return;
  }

  /// Send a stanza.
  ///
  /// This function is called to push data onto the send queue to go out over
  /// the wire. Whenever a request is sent to the BOSH server, all pending data
  /// is sent and the queue is flushed.
  ///
  /// * @param presence The stanza to send
  // void send({xml.XmlElement? presence}) {
  //   if (presence == null) return;
  // }

  /// Immediately send any pending outgoing data.
  ///
  /// Normally send() queues outgoing data until the next idle period (100ms),
  /// which optimizes network use in the common cases when several send()s are
  /// called in succession. flush() can be used to immediately send all pending
  /// data.
  void flush() {
    /// Cancel pending idle period and run the idle function immediately.
    _onIdle();
  }

  /// Send a stanza.
  ///
  /// This method is called to push data onto the send queue to go out over
  /// the wire. Whenever a request is send to the BOSH server, all pending data
  /// is sent and the queue is flushed.
  ///
  /// The message type can be [xml.XmlElement], or list of [xml.XmlElement], or
  /// just [EchoBuilder].
  void send(dynamic message) {
    /// If the message is null or empty, exit from the function.
    if (message == null) return;

    /// If the message is list, then queue all the elements inside of it.
    if (message is List<xml.XmlElement>) {
      for (int i = 0; i < message.length; i++) {
        _queueData(message[i]);
      }
    }

    /// If the message type is [EchoBuilder] then queue the node tree inside of
    /// it.
    else if (message.runtimeType == EchoBuilder) {
      _queueData((message as EchoBuilder).nodeTree);
    }

    /// If the message type is [xml.XmlElement], then queue only it.
    else {
      _queueData(message);
    }

    /// Run the protocol send function to flush all the available data.
    protocol!.send();
  }

  void _queueData(dynamic element) {
    if (element == null) {
      throw Exception('Cannot queue empty element.');
    }
    if (element is xml.XmlElement) {
      if (element.children.isEmpty || element.name.local.isEmpty) {
        throw Exception('Cannot queue empty element.');
      }
    }
    data!.add(element);
  }

  /// Send an xmpp:restart stanza.
  void sendRestart() {
    data!.add('restart');
    protocol!.sendRestart();

    /// Set idle timeout to 100 `milliseconds` for invocation of `_onIdle`.
    _idleTimeout = Timer(const Duration(milliseconds: 100), _onIdle);
  }

  /// Add a timed handler to the connection.
  ///
  /// This function adds a timed handler. The provided handler will be called
  /// every period milliseconds until it returns false, the connection is
  /// terminated, or the handler is removed. Handlers that wish to continue
  /// being invoked should return true.
  ///
  /// Because of method binding it is necessary to save the result of this
  /// function if yuo wish to remove a handler `deleteTimedHandler()`.
  ///
  /// Note that user handlers are not active until authentication is successful.
  ///
  /// * @param int period The period of the handler.
  /// * @param handler The callback function.
  /// * @return A reference to the handler that can be used to remove it.
  _TimedHandler addTimedHandler(int period, void Function() handler) {
    /// Declare new [_TimedHandler] object using passed params.
    final timed = _TimedHandler(period: period, handler: handler);

    /// Add created [_TimedHandler] to `addTimeds` list.
    addTimeds!.add(timed);
    return timed;
  }

  /// Delete a timed handler for a connection.
  ///
  /// This function removes a timed handler from the connection. The `reference`
  /// paramter is not the function passed to `addTimedHandler()`, but the
  /// reference returned from `addTimedHandler()` method.
  ///
  /// * @param reference The handler reference.
  void deleteTimedHandler(_TimedHandler reference) {
    /// This must be done in the Idle loop so that we do not change the handlers
    /// during iteration.
    removeTimeds!.add(reference);
  }

  /// Add a stanza handler for the connection.
  ///
  /// This function adds a stanza handler to the connection. The handler
  /// callback will be called for any stanza that matches the parameters.
  ///
  /// Note that if multiple parameters are supplied, they must all match for the
  /// handler to be invoked.
  ///
  /// The handler will receive the stanza that triggered it as its argument.
  /// __The handler should return true if it is to be invoked again;returning
  /// false will remove the handler after it returns.__
  ///
  /// As a convenience, the `namespace` parameter applies to the top level
  /// element and also any of its immediate children. This is primarily to make
  /// matching /iq/query elements ease.
  ///
  /// * Options
  /// <br /> With the argument, you can specify boolean flags that affect how
  /// matches are being done.
  ///
  /// Currently two flags exist:
  ///
  /// - matchBareFromJid:
  ///   <br/ > When set to true, the from parameter and the `from` attribute
  ///   on the stanza will be matches as bare JIDs instead of full JIDs. To use
  ///   this, pass {'matchBareFromJid': true} as the value of options. The
  ///   default value for `matchBareFromJid` is `false`.
  ///
  /// - ignoreNamespaceFragment:
  ///   <br /> When set to true, a fragment specified on the stanza's namespace
  ///   URL will be ignored when it is matched with the one configured for the
  ///   handler.
  ///
  /// The return value will be saved if the user wish to remove the handler with
  /// `deleteHandler()`.
  ///
  /// * @param handler The user callback.
  /// * @param namespace The namespace to match.
  /// * @param name The stanza name to match.
  /// * @param type The stanza type (or types if an array) to match. This can be
  /// [String] or [List].
  /// * @param id The stanza id attribute to match.
  /// * @param from The stanza from attribute to match.
  /// * @param options The handler options
  /// * @return A reference to the handler that can be used to remove it.
  _Handler addHandler({
    /// The user callback.
    String? namespace,

    /// The namespace to match.
    String? name,

    /// The stanza name to match.
    String? id,

    /// The stanza `from` attribute to match.
    String? from,

    /// The stanza type.
    dynamic type,

    /// The handler options.
    Map<String, bool>? options,

    /// The user callback.
    bool Function([xml.XmlElement])? handler,
  }) {
    /// Create new [_Handler] object.
    final hand = _Handler(
      handler: handler,
      name: name,
      namespace: namespace,
      type: type,
      id: id,
      from: from,
      options: options,
    );

    /// Add handlers to the list.
    addHandlers!.add(hand);
    return hand;
  }

  /// Delete a stanza handler for a connection.
  ///
  /// This function removes a stanza handler from the connection. The
  /// `reference` parameter is not the function passed to `addHandler()`,
  /// but is the reference returned from `addHandler()`.
  ///
  /// * @param reference The handler reference.
  void deleteHandler(_Handler reference) {
    /// Add [_Handler] reference to the list of to be removed handlers.
    ///
    /// This must be done in the Idle loop so that we do not change the
    /// handlers during iteration.
    removeHandlers!.add(reference);

    /// Get the index of handler from the handler list.
    final i = addHandlers!.indexOf(reference);
    if (i >= 0) {
      /// Remove the dedicated handler.
      addHandlers!.removeAt(i);
    }
  }

  /// Register the SASL mechanisms which will be supported by this instance of
  /// [Echo] (i.e. which this XMPP client will support).
  ///
  /// * @param mechanisms Array of objects which extend [SASL] concrete class.
  void registerMechanisms() {
    /// Register variable as empty beforehand.
    mechanisms = {};

    /// The list of all available authentication mechanisms.
    late final mechanismList = <SASL>[
      SASLAnonymous(this),
      SASLExternal(this),
      SASLOAuthBearer(this),
      SASLXOAuth2(this),
      SASLPlain(this),
      SASLSHA1(this),
      SASLSHA256(this),
      SASLSHA384(this),
      SASLSHA512(this),
    ];
    mechanismList.map((mechanism) => registerSASL(mechanism));
  }

  /// Register a single [SASL] mechanism, to be supported by this client.
  ///
  /// * @param mechanism SASL type auth object.
  void registerSASL(SASL mechanism) => mechanisms![mechanism.name] = mechanism;

  /// Start the graceful disconnection process.
  ///
  /// This function starts the disconnection process. This process starts by
  /// sending unavailable presence and sending BOSH body of type terminate.
  ///
  /// A timeout handler makes sure that disconnection happens even if the BOSH
  /// server does not respond.
  ///
  /// if The user supplied connection callback will be notified of the progress
  /// as this process happens.
  ///
  /// * @param reason The reason the disconnect is occuring.
  void disconnect(String? reason) {
    /// Change the status of connection to disconnecting.
    changeConnectStatus(Status.disconnecting, reason);

    /// Log according to the `reason` value.
    if (reason != null) {
      Log().warn('Disonnect was called because: $reason');
    } else {
      Log().info('Disconnect was called');
    }

    /// Proceed if [Echo] is connected to the server.
    if (connected!) {
      /// Nullable `presence` decleration of the [EchoBuilder] object.
      EchoBuilder? presence;

      /// Change disconnecting flag to true.
      disconnecting = true;

      /// Proceed if user is authenticated.
      if (authenticated!) {
        presence = EchoBuilder.pres(
          attributes: {'xmlns': ns['CLIENT'], 'type': 'unavailable'},
        );
      }
      _disconnectTimeout = _addSystemTimedHandler(
        disconnectionTimeout!,
        _onDisconnectTimeout.call,
      );
      protocol!.disconnect(presence!.nodeTree);
    }

    /// Else proceed to this scope.
    else {
      Log().warn('Disconnect was called before Echo connected to the server.');
      protocol!.abortAllRequests();
      doDisconnect();
    }
  }

  /// Disconnects the XMPP connection.
  ///
  /// This is the last piece of the disconnection logic. This resets the
  /// connection and alerts the user's connection callback.
  ///
  /// It takes an optional [condition] parameter which represents the reason or
  /// condition for disconnecting.
  void doDisconnect([String? condition]) {
    /// If the [_disconnectTimeout] is set, it will be canceled by calling the
    /// [deleteTimedHandler] method with the [_disconnectTimeout] as the argument.
    if (_disconnectTimeout != null) {
      deleteTimedHandler(_disconnectTimeout!);
      _disconnectTimeout = null;
    }

    /// Logs the disconnection event.
    Log().log('_doDisconnect was called');

    /// Invokes `doDisconnect` method which is declared as [Protocol] object
    /// method.
    protocol!.doDisconnect();

    /// Resetting internal flags and variables.
    authenticated = false;
    disconnecting = false;
    restored = false;

    /// Clearing lists.
    handlers = [];
    timedHandlers = [];
    removeTimeds = [];
    removeHandlers = [];
    addTimeds = [];
    addHandlers = [];

    /// Change connection status of the server to disconnecting to indicate that
    /// the process is in the state of disconnecting.
    changeConnectStatus(Status.disconnected, condition);

    /// Finally, make connected property false.
    connected = false;
  }

  /// Handler to processes incoming data from the connection.
  ///
  /// Except for `connectCB` handling the initial connection request,
  /// this function handles the incoming data for all requests. This function
  /// also fires stanza handlers that match each incoming stanza.
  ///
  /// * @param request The request that has data ready
  /// * @param raw The stanza as a raw string (optional)
  void dataRecv(xml.XmlElement request, [String? raw]) {
    final element = protocol!.reqToData(request);
    if (element == null) return;

    if (element.name.local == protocol!.strip && element.children.isNotEmpty) {
      xmlInput(element.children[0]);
    } else {
      xmlInput(element);
    }

    if (raw != null) {
      rawInput(raw);
    } else {
      rawInput(Utils.serialize(element));
    }

    /// Remove handlers scheduled for deletion.
    while (removeHandlers!.isNotEmpty) {
      final hand = removeHandlers!.last;
      final i = handlers!.indexOf(hand);
      if (i >= 0) {
        handlers!.removeAt(i);
      }
    }

    /// Add handlers scheduled for deletion.
    while (addHandlers!.isNotEmpty) {
      handlers!.add(addHandlers!.last);
    }

    /// Handle graceful disconnect
    if (disconnecting!) {
      doDisconnect();
      return;
    }

    final type = element.getAttribute('type');
    if (type != null && type == 'terminate') {
      /// Do not process stanzas that come in after disconnect.
      if (disconnecting!) {
        return;
      }

      /// An error occured.
      String? condition = element.getAttribute('condition');
      final conflict = element.getElement('conflict');
      if (condition != null) {
        if (condition == 'remote-stream-error' &&
            conflict!.childElements.isNotEmpty) {
          condition = 'conflict';
        }
        changeConnectStatus(Status.connfail, condition);
      } else {
        changeConnectStatus(Status.connfail, errorCondition['UNKNOWN_REASON']);
      }
      doDisconnect(condition);
      return;
    }

    /// Send each incoming stanza through the handler chain.
    Utils.forEachChild(element, null, (child) {
      final matches = [];
      handlers = handlers!.fold<List<_Handler>>(<_Handler>[],
          (List<_Handler> updatedHandlers, _Handler handler) {
        try {
          if (handler.isMatch(child as xml.XmlElement) &&
              (authenticated! || !handler.user)) {
            if (handler.run(child) != null) {
              updatedHandlers.add(handler);
            }
            matches.add(handler);
          } else {
            updatedHandlers.add(handler);
          }
        } catch (e) {
          // if the handler throws an exception, we consider it as false
          Log().warn('Removing Strophe handlers due to uncaught exception: $e');
        }
        return updatedHandlers;
      });
    });
  }

  /// Sends an IQ to the XMPP server to bind a JID resource for this session.
  ///
  /// https://tools.ietf.org/html/rfc6120#section-7.5
  ///
  /// If `explicitResourceBinding` was set to a truthy value in the options
  /// passed to the [Echo] consructor, then this function needs to be called
  /// by the client author.
  ///
  /// Otherwise it will be called automatically as soon as the XMPP server
  /// advertises the 'urn:ietf:params:xml:ns:xmpp-bind' stream feature.
  void bind() {
    if (!doBind!) {
      Log().info('Echo bind called but "do_bind" is false');
      return;
    }
    final resource = Utils().getResourceFromJID(jid!);
    if (resource != null) {
      send(
        EchoBuilder.iq(
          attributes: {'type': 'set', 'id': '_bind_auth_2'},
        )
            .c('bind', attributes: {'xmlns': ns['BIND']!})
            .c('resource')
            .t(resource)
            .nodeTree,
      );
    } else {
      send(
        EchoBuilder.iq(
          attributes: {'type': 'set', 'id': '_bind_auth_2'},
        ).c('bind', attributes: {'xmlns': ns['BIND']!}).nodeTree,
      );
    }
  }

  /// Private handler for binding result and session start.
  ///
  /// * @param element XmlElement matching stanza.
  /// * @return false to remove the handler.
  bool? _onResourceBindResultIQ(xml.XmlElement element) {
    if (element.getAttribute('type') == 'error') {
      Log().warn('Resource binding failed.');
      final conflict = element.getElement('conflict');
      String? condition;
      if (conflict != null) {
        condition = errorCondition['CONFLICT'];
      }
      changeConnectStatus(Status.authFail, condition);
      return false;
    }
    final bind = element.getElement('bind');
    if (bind != null) {
      final jidNode = bind.getElement('jid');
      if (jidNode != null) {
        authenticated = true;
        jid = Utils.getText(element);
        if (doSession!) {
          _establishSession();
        } else {
          changeConnectStatus(Status.connected, null);
        }
      }
    } else {
      Log().warn('Resource binding failed.');
      changeConnectStatus(Status.authFail, null, element);
      return false;
    }
  }

  /// SASL authentication will be attempted if available, otherwise the code
  /// will fall back to legaacy authentication.
  ///
  /// * @param request The current request
  /// * @param callback Low level (xmpp) connect callback function.
  void connectCB(
    xml.XmlElement request,
    void Function(Echo)? callback, [
    String? raw,
  ]) {
    Log().log('connectCB was called');
    connected = true;

    xml.XmlElement? bodyWrap;
    try {
      bodyWrap = protocol!.reqToData(request);
    } catch (error) {
      changeConnectStatus(Status.connfail, errorCondition['BAD_FORMAT']);
      doDisconnect(errorCondition['BAD_FORMAT']);
    }

    if (bodyWrap == null) return;
    if (bodyWrap.name.qualified == protocol!.strip &&
        bodyWrap.children.isNotEmpty) {
      xmlInput(bodyWrap.children.first);
    } else {
      xmlInput(bodyWrap);
    }

    if (raw != null) {
      rawInput(raw);
    } else {
      rawInput(Utils.serialize(bodyWrap));
    }

    final connectectionCheck = protocol!.connectCB(bodyWrap);
    if (connectectionCheck == status[Status.connfail]) {
      return;
    }

    /// Check for the stream:features tag
    bool hasFeatures;
    hasFeatures =
        bodyWrap.getElement(ns['STREAM']!, namespace: 'features') != null;
    if (!hasFeatures) {
      protocol!.nonAuth(callback);
      return;
    }

    final matched = List.from(
      bodyWrap.childElements
          .where((element) => element.getElement('mechanism') != null),
    )
        .map(
          (mechanism) =>
              mechanisms![(mechanism as xml.XmlElement).name.qualified],
        )
        .where((element) => element != null)
        .toList();

    if (matched.isEmpty) {
      if (bodyWrap.childElements
          .map((element) => element.getElement('auth'))
          .toList()
          .isEmpty) {
        /// There are no matching SASL mechanisms and also no legacy auth
        /// available.
        protocol!.nonAuth(callback);
        return;
      }
    }
    if (doAuthentication!) {
      authenticate(matched);
    }
  }
  void authenticate(List<SASL?> mechanisms) {
    _attemptSASLAuth()
  }


  /// Sorts a list of objects with prototype SASLMechanism according to their
  /// properties.
  List<SASL> sortMechanismsByPriority(List<SASL?> mechanisms) {
    final mechs  = <SASL>[];
    /// Iterate over all the available mechanisms.
    for (int i = 0 ; i < mechanisms.length - 1; i++) {
      int higher = i;
      for (int j = i  + 1 ; j < mechanisms.length; ++j) {
        if (mechs[j].priority! > mechs[higher].priority!) {
          higher = j;
        }
      }
      if (higher != i) {
        final swap = mechanisms[i];
        mechs[i] = mechanisms[higher]!;
mechs[higher] = swap!;
      }
    }
    return mechs;
  }
  /// Iterate through an array of SASL mechanisms and attempt authentication
  /// with the hightes priority (enabled) mechanism.
  /// 
  /// * @param mechanisms List of [SASL] mechanisms.
  /// * @return [bool] true or false, depending on whether a valid SASL
  /// mechanism was found with which authentication could be started.
bool _attemptSASLAuth(List<SASL?> mechanisms) {
  final mechs = sortMechanismsByPriority(mechanisms);
  bool mechanismFound = false;
  for (int i = 0 ; i < mechs.length; i++) {
    if (mechs[i].test()) {
      continue;
    }
    _saslSuccessHandler = _addSystemHandler(
      
    );
  }
}
  void _saslChallengeCb() {}
  void _attemptLegacyAuth() {}
  void _onLegacyAuthIQResult() {}
  void _saslSuccessCb() {}
  void _onStreamFeaturesAfterSASL() {}
  void _establishSession() {}
  void _onSessionResultIQ() {}
  void _saslFailureCb() {}
  void _auth2Cb() {}
  void _onDisconnectTimeout() {}

  void _onIdle() {}

  /// Private function to add a system level timed handler.
  ///
  /// This function is used to add [_TimedHandler] for the library code. System
  /// timed handlers are allowed to run before authentication is complete.
  ///
  /// * @param period The period of the handler.
  /// * @param handler The callback function.
  _TimedHandler _addSystemTimedHandler(int period, void Function() handler) {
    /// Create [_TimedHandler] first, for adding to the created handler list.
    final timed = _TimedHandler(period: period, handler: handler);

    /// Set the user to false.
    timed.user = false;

    /// Add created handler to the list of timed handlers.
    addTimeds!.add(timed);
    return timed;
  }

  /// Private method to add a system level stanza handler.
  ///
  /// This function is used to add [_Handler] for the library code. System
  /// stanza handlers are allowed to run before authentication is complete.
  ///
  /// * @param handler The callback function.
  /// * @param namespace The namespace match.
  /// * @param name The stanza name to match.
  /// * @param type The stanza type attribute to match.
  /// * @param id The stanza id attribute to match.
  _Handler _addSystemHandler({
    /// The user callback.
    String? namespace,

    /// The namespace to match.
    String? name,

    /// The stanza name to match.
    String? id,

    /// The stanza type.
    dynamic type,

    /// The user callback.
    bool Function([xml.XmlElement])? handler,
  }) {
    /// Create [_Handler] for passing to the system handler list.
    final hand = _Handler(
      handler: handler,
      namespace: namespace,
      name: name,
      type: type,
      id: id,
    );

    /// Equal to false for indicating that this is system handler.
    hand.user = false;

    /// Add created [_Handler] to the list.
    addHandlers!.add(hand);

    return hand;
  }
}

/// Private helper class for managing stanza handlers.
///
/// Encapsulates a user provided callback function to be executed when matching
/// stanzas are received by the connection.
///
/// Handlers can be either one-off or persistant depending on their return
/// value. Returning true will cause a Handler to remain active, and returning
/// false will remove the Handler.
///
/// Users will not use Handlers directly, instead they will use
/// `Echo.addHandler()` or `Echo.deleteHandler()` method.
class _Handler {
  _Handler({
    /// The function to handle the XMPP stanzas.
    this.handler,

    /// The namespace of the stanzas to match. If null, all namespaces will be
    /// considered a match.
    this.namespace,

    /// The name of the stanzas to match. If null, all names will be considered
    /// a match.
    this.name,

    /// The type of the stanzas to match. If null, all types will be considered
    /// a match.
    this.type,

    /// The id of the stanzas to match. If null, all ids will be considered a
    /// match.
    this.id,

    /// The source of the stanzas to match. If null, all sources will be
    /// considered a match.
    String? from,

    /// Additional options for the handler.
    ///
    Map<String, bool>? options,
  }) : options = options ??
            {
              /// If set to true, it indicates that the from attribute should
              /// be matched with the bare JID (Jabber ID) instead of the full
              /// `JID`.
              ///
              /// Default is `false`.
              'matchBareFromJid': false,

              /// If set to true, it indicates that the namespace should be
              /// compared without considering any fragment after the '#'
              /// character.
              ///
              /// Default is false.
              'ignoreNamespaceFragment': false,
            } {
    if (options!.containsKey('matchBare')) {
      Log().warn(
        'The "matchBare" option is deprecated, use "matchBareFromJid" instead.',
      );
      this.options!['matchBareFromJid'] = options['matchBareFromJid']!;
      options.remove('matchBare');
    }
    if (options.containsKey('matchBareFromJid')) {
      this.from = from != null ? Utils().getBareJIDFromJID(from) : null;
    } else {
      this.from = from;
    }

    /// Whether the handler is a user handler or a system handler.
    user = true;
  }

  /// The source of the stanzas to match.
  String? from;

  /// The `namespace` of the stanzas to match, If null, all namespaces will be
  /// considered a match.
  final String? namespace;

  /// The `name` of the stanzas to match.
  final String? name;

  /// The `type` of the stanzas to match. Can be used as [String] or [List].
  final dynamic type;

  /// The `id` of the stanzas to match.
  final String? id;

  /// Additional `options` for the handler.
  final Map<String, bool>? options;

  /// Authentication flag for the handler.
  bool user = false;

  /// The `function` to handle the XMPP stanzas.
  final bool Function([xml.XmlElement element])? handler;

  /// Retrieves the namespacce of an XML element.
  String? getNamespace(xml.XmlElement element) {
    /// Defaults to the attribute of `xlmns`.
    String? namespace = element.getAttribute('xlmns');

    /// If not null and the options contain dedicated param, then split `#` sign
    /// from `namespace`.
    if (namespace != null && options!['ignoreNamespaceFragment']!) {
      namespace = namespace.split('#')[0];
    }
    return namespace;
  }

  /// Checks if the namespace of an XML element matches the specified namespace.
  ///
  /// * @param element The XML element to check.
  /// * @return True if the element's namespace matches the specified namespace.
  /// Otherwise `false`.
  bool namespaceMatch(xml.XmlElement element) {
    /// Defaults to false.
    bool isNamespaceMatches = false;

    /// If null then return true that namespace matches.
    if (namespace == null) return true;
    Utils.forEachChild(element, null, (node) {
      if (getNamespace(element) == namespace) {
        isNamespaceMatches = true;
      }
    });
    return isNamespaceMatches || getNamespace(element) == namespace;
  }

  /// Checks if an XML element matches the specified criteria.
  ///
  /// * @param element The XML element to check.
  /// * @return True if the element matches the specified criteria. Otherwise
  /// `false`.
  bool isMatch(xml.XmlElement element) {
    /// Default to the attribute under name of `from` on the passed `element`
    String? from = element.getAttribute('from');

    if (options!['matchBareFromJid']!) {
      from = Utils().getBareJIDFromJID(from!);
    }
    final elementType = element.getAttribute('type');
    if (namespaceMatch(element) &&
        (name == null || Utils.isTagEqual(element, name!)) &&
        (type == null || type is List
            ? (type! as List).contains(elementType)
            : elementType == type) &&
        (id == null || element.getAttribute('id') == id) &&
        (from == null || from == this.from)) {
      return true;
    }
    return false;
  }

  /// Runs the handler function on the specified XML element.
  ///
  /// * @param element The XML element to process.
  /// * @return The result of the handler function, if available.
  /// Otherwise returns null.
  bool? run(xml.XmlElement element) {
    bool? result;
    try {
      result = handler!.call(element);
    } catch (e) {
      Echo._handleError(e);
    }
    return result;
  }

  @override
  String toString() => '{Handler: $handler ($name, $id, $namespace)}';
}

/// Private helper class for managing timed handlers.
///
/// Encapsulates a user provided callback that should be called after a certain
/// period of time or at regulra intervals. The return value of the callback
/// determines whether the [_TimedHandler] will continue to fire.
///
/// Users will not use this class objects directly, but instead
/// they will use this class's `addTimedHandler()` method and
/// `deleteTimedHandler()` method.
class _TimedHandler {
  _TimedHandler({
    required this.period,
    required this.handler,
  }) {
    /// Equal the last call time to now.
    lastCalled = DateTime.now();
  }

  /// The number of milliseconds to wait before the handler is called.
  final int period;

  /// The callback to run when the handler fires. This function should take no
  /// arguments.
  final void Function() handler;

  bool user = true;

  /// Nullable param for indicating lastCalled time of the handler.
  DateTime? lastCalled;

  /// Run the callback for the [_TimedHandler].
  ///
  /// * @return `true` if the [_TimedHandler] should be called again, otherwise
  /// false.
  void run() {
    /// Equals last called time to now.
    lastCalled = DateTime.now();

    /// Calls handler.
    return handler.call();
  }

  /// Reset the last called time for the [_TimedHandler].
  void reset() {
    /// Equals `lastCalled` variable to `DateTime.now()`.
    lastCalled = DateTime.now();
  }

  /// Get a string representation of the [_TimedHandler] object.
  @override
  String toString() => '''TimedHandler: $handler ($period)''';
}
