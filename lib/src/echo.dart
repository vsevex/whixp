import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'package:echo/src/builder.dart';
import 'package:echo/src/constants.dart';
import 'package:echo/src/log.dart';
import 'package:echo/src/protocol.dart';
import 'package:echo/src/sasl.dart';
import 'package:echo/src/utils.dart';
import 'package:meta/meta.dart';

import 'package:xml/xml.dart' as xml;

part 'sasl_anon.dart';
part 'sasl_external.dart';
part 'sasl_oauthbearer.dart';
part 'sasl_plain.dart';
part 'sasl_sha1.dart';
part 'sasl_sha256.dart';
part 'sasl_sha384.dart';
part 'sasl_sha512.dart';
part 'sasl_xoauth2.dart';
part 'scram.dart';
part 'websocket.dart';

/// Defines void Function callback for assigning methods like `_xmlInput`,
/// `_rawInput`.
typedef ExternalFunction = void Function(dynamic element);

class Echo {
  /// The [Echo] class represents an XMPP client connection.
  ///
  /// It provides functionality for establishing a connection, handling
  /// protocols, authentication and managing XMPP stanzas.
  Echo({
    /// The XMPP service URL.
    required this.service,

    /// Optional configuration options.
    this.options = const <String, dynamic>{},
  }) {
    /// The connected JID
    jid = '';

    /// The JIDs domain
    _domain = null;

    /// stream:features
    // _features = null;

    /// SASL
    _saslData = {};

    /// Equals to null.
    _disconnectTimeout = null;

    /// Equal to empty map.
    _mechanisms = {};

    /// Supported protocol error handlers.
    // _protocolErrorHandlers = {
    //   'HTTP': {},
    //   'websocket': {},
    // };

    /// Allows to make authentation.
    _doAuthentication = true;

    /// Initial value for `paused` is false.
    _paused = false;

    /// Call onIdle callback every 1/10th of a second.
    _idleTimeout =
        Timer.periodic(const Duration(milliseconds: 100), (_) => _onIdle);

    /// Sets the communication protocol based on the provided options.
    _setProtocol();

    /// Supported connection plugins.
    // _connectionPlugins = {};

    /// Initialize the start point.
    reset();

    /// Register all available [SASL] auth mechanisms.
    _registerMechanisms();

    /// A client must always respond to incoming IQ 'set' or 'get' stanzas.
    ///
    /// This is a fallback handler which gets called when no other handler was
    /// called for a received IQ 'set' or 'get'.
    _iqFallbackHandler = Handler(
      handler: ([iq]) {
        send(
          EchoBuilder.iq(
            attributes: {
              'type': 'error',
              'id': iq!.getAttribute('id'),
            },
          ).c('error', attributes: {'type': 'cancel'}).c(
            'service-unavailable',
            attributes: {'xmlns': ns['STANZAS']!},
          ),
        );
        return true;
      },
      name: 'iq',
      type: ['get', 'set'],
    );

    /// TODO: implement plugin initialization method in this scope.
  }

  /// `version` constant.
  final String version = '1.0.0';

  /// The service URL.
  late String service;

  /// Configuration options.
  final Map<String, dynamic> options;

  /// Jabber identifier of the user.
  late String jid;

  /// Domain part of the given JID.
  String? _domain;

  /// [xml.XmlElement] type features for later assign.
  // xml.XmlElement? _features;

  /// [Protocol] which will be responsible for keeping the type of connection.
  late Protocol _protocol;

  /// Timeout for indicating when the service need to disconnect. Representing
  /// in milliseconds.
  late int _disconnectionTimeout;

  /// Disconnect timeout in the type of [_TimedHandler].
  _TimedHandler? _disconnectTimeout;

  /// Authentication identifier of the connection.
  late String? _authcid;

  /// Authorization identity (username)
  late String? _authzid;

  // Handler? iqFallbackHandler;

  /// dynamic type password. This can be either [String] or [Map].
  dynamic _password;

  /// Values can be either [String] or a [Map].
  late final Map<String, dynamic>? _saslData;

  /// Holds all available mechanisms that are supported by the server.
  Map<String, SASL>? _mechanisms;

  late bool _doAuthentication;
  late bool _authenticated;
  late bool _connected;
  late bool _disconnecting;
  late bool _paused;
  late bool _doBind;
  late bool _doSession;

  /// Data holder for sending later on. The data it can hold is can be [String]
  /// or [xml.XmlElement].
  late final List _data = <dynamic>[];

  /// The SASL SCRAM client and server keys. This variable will be populated
  /// with a non-null object of the above described form after a successful
  /// SCRAM connection.
  // late List<String> _scramKeys = [];

  /// This variable appears to be a list used to store instances of the
  /// [Handler] class, representing XMPP stanza handlers.
  late final List<Handler> _addHandlers = [];

  /// This variable appears to be alist used to store instance of the
  /// [Handler] class which is meant to be removed.
  late final List<Handler> _removeHandlers = [];

  /// List of [_TimedHandler]s.This list stores timed handlers. It is declared
  /// using the `late` keyword, which means it is initialized lazily and can
  /// be assigned a value later in the code. It is not declared as `final` due
  /// it can be reassigned in the code later.
  late List<_TimedHandler> _timedHandlers = [];

  /// This variable is a list that stores instances of [_Handler] class. It is
  /// declared using `late`, which means it is initialized lazily and can be
  /// assigned a value later in code.
  late List<Handler> _handlers = [];

  /// This variable appears to be a list used to store references to timed
  /// handlers that should be removed.
  late final List<_TimedHandler> _removeTimeds = [];

  /// The addTimeds variable appears to be a list that holds instances of
  /// [_TimedHandler] objects. It is used to store and manage timed handlers
  /// that have been added using the `addTimedHandler` method
  late final List<_TimedHandler> _addTimeds = [];

  /// The _idleTimeout variable is a Timer object that handles the idle timeout
  /// functionality. The purpose of this timer is to invoke the `_onIdle`
  /// method after a specific duration of idle time. Idle time refers to the
  /// period during which no activity or interaction occurs.
  late Timer _idleTimeout;

  /// The selected mechanism to provide authentication.
  late SASL? _mechanism;

  /// External executer for `_xmlInput`.
  ExternalFunction? xmlInput;

  /// External executer for `_xmlOutput`.
  ExternalFunction? xmlOutput;

  /// External executer for `_rawInput`.
  ExternalFunction? rawInput;

  /// External executer for `_rawOutput`.
  ExternalFunction? rawOutput;

  /// This variable represents a function that can be assigned to handle the
  /// connection status and related data after a connection attempt.
  late final Function(EchoStatus, [String?, xml.XmlElement?])? _connectCallback;

  /// This variable holds an instance of the [Handler] class that serves as a
  /// fallback handler for IQ (Info/Query) stanzas.
  ///
  /// IQ stanzas are used for exchanging structured data between XMPP entities.
  /// When an incoming IQ stanza is received and no other specific handler is
  /// registered to handle it, the fallback handler is triggered.
  ///
  /// The purpose of the `_iqFallbackHandler` is to handle IQ stanzas that
  /// don't have a dedicated handler assigned to them. It ensures that there is
  /// always a response to incoming IQ stanzas, even if the specific handling
  /// logic is not defined.
  late final Handler _iqFallbackHandler;

  /// This variable holds an instance of the [Handler] class that is responsible
  /// for handling successful SASL (Simple Authentication and Security Layer)
  /// authentication. It is initially set to `null`.
  ///
  /// SASL authentication is a mechanism used to securely authenticate clients
  /// and servers in XMPP communication. When the SASL authentication process
  /// succeeds, the `_saslSuccessHandler` is triggered.
  ///
  /// The purpose of the `_saslSuccessHandler` is to handle the successful
  /// authentication event and perform any necessary actions or logic associated
  /// with it, such as establishing a session or initializing further
  /// communication.
  late Handler? _saslSuccessHandler;

  /// This variable holds an instance of the Handler class that is responsible
  /// for handling failed SASL (Simple Authentication and Security Layer)
  /// authentication. It is initially set to `null`.
  ///
  /// If the SASL authentication process fails, the `_saslFailureHandler` is
  /// triggered. This handler allows for handling and reacting to authentication
  /// failures, such as incorrect credentials or unsupported authentication
  /// methods.
  ///
  /// The purpose of the `_saslFailureHandler` is to handle the failed
  /// authentication event and perform any necessary actions or logic associated
  /// with it, such as displaying an error message or taking corrective
  /// measures.
  late Handler? _saslFailureHandler;

  /// This variable holds an instance of the Handler class that is responsible
  /// for handling SASL (Simple Authentication and Security Layer)
  /// authentication challenges. Defaults to `null`.
  ///
  /// During the SASL authentication process, challenges may be sent from the
  /// server to the client, requiring additional information or responses. The
  /// `_saslChallengeHandler` is triggered when such challenges are received.
  late Handler? _saslChallengeHandler;

  /// [Map] used to store protocol error handlers. It is structured as a nested
  /// map, where the outer map is indexed by the protocol name (e.g. `HTTP`),
  /// and the inner map is indexed by the status code associated with the error.
  ///
  /// Each status code is mapped to a callback function that will be invoked
  /// when the corresponding error occurs.
  // Map<String, dynamic>? _connectionPlugins;

  /// Protocol map holder.
  // Map<String, Map<int, Function>>? _protocolErrorHandlers;

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

  /// Select protocol based on `options` or `service`.
  ///
  /// Sets the communication protocol based on the provided options. THis can
  /// be `BOSH` connection (for later updates, not for now), `Websocket`, or
  /// `WorkerWebsocket` connection.
  void _setProtocol() {
    /// Try to get protocol from `options`, else assign empty string.
    final protocol = options['protocol'] as String? ?? '';

    /// Check if Websocket implementation should be used.
    if (service.startsWith('ws:') ||
        service.startsWith('wss:') ||
        protocol.startsWith('ws')) {
      /// Set protocol to [Websocket].
      _protocol = Websocket(this);
    }

    /// If not using a Websocket, check for websocket worker or secure Websocket
    /// worker service.
    else if (options['worker'] != null && options['worker'] as bool) {
      /// TODO: implement worker web socket.
    } else {
      Log().warn('No service was found under: $service');
      _doDisconnect();
      return;
    }
  }

  // void addConnectionPlugin(String name, dynamic pluginType) {
  //   _connectionPlugins![name] = pluginType;
  // }

  /// Resets the XMPP client to its initial state.
  ///
  /// It clears various lists, flags and data related to the client's
  /// configuration, authentication status, connection status, and other
  /// internal states.
  void reset() {
    /// Call the reset method to reset the underlying protocol implementation
    /// (represented by _protocol) to its initial state.
    _protocol.reset();

    /// Clear [_Handler] holder list.
    _handlers.clear();

    /// Clear the handler holder list.
    _addHandlers.clear();

    /// Clear the handler list that need to be removed.
    _removeHandlers.clear();

    /// Clear the timed handler list.
    _timedHandlers.clear();

    /// Clear added timed handler list.
    _addTimeds.clear();

    /// Clear timed handler list which is assigned for removal later.
    _removeTimeds.clear();

    /// Clear _data list.
    _data.clear();

    /// Is authenticated or not holder. Resets to false.
    _authenticated = false;

    /// Is connected or not holder. Resets to false.
    _connected = false;

    /// Is disconnecting or not holder. Resets to false.
    _disconnecting = false;

    /// Is do bind enabled or not holder. Resets to false.
    _doBind = false;

    /// Is do session enabled or not holder. Resets to false.
    _doSession = false;
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
  void pause() => _paused = true;

  /// Resume the request manager.
  ///
  /// This resumes after `pause()` has been called.
  void resume() => _paused = false;

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
  // String _getUniqueId(dynamic suffix) {
  //   /// It follows the format specified by the UUID version 4 standart.
  //   final uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
  //       .replaceAllMapped(RegExp('[xy]'), (match) {
  //     final r = math.Random.secure().nextInt(16);
  //     final v = match.group(0) == 'x' ? r : (r & 0x3 | 0x8);
  //     return v.toRadixString(16);
  //   });

  //   /// Check whether the provided suffix is [String] or [int], so if type is
  //   /// one of them, proceed to concatting.
  //   if (suffix is String || suffix is num) {
  //     return '$uuid:$suffix';
  //   } else {
  //     return uuid;
  //   }
  // }

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
  // void addProtocolErrorHandler(
  //   /// Dedicated protocol for handling errors. For now only can accept `HTTP`.
  //   String protocol,

  //   /// Status code of the error.
  //   int statusCode,

  //   /// The callback that will be executed when the error occured.
  //   void Function() callback,
  // ) =>
  //     _protocolErrorHandlers![protocol]![statusCode] = callback;

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
    /// User's `Jabber` identifier.
    required String jid,

    /// The user's password.
    dynamic password,

    /// The connection callback function.
    void Function(EchoStatus)? callback,

    /// Optional alternative authentication identifier.
    String? authcid,

    /// Disconnection timeout before terminating.
    int disconnectionTimeout = 3000,
  }) {
    /// Equal gathered `jid` to global one.
    ///
    /// Authorization identity.
    this.jid = jid;

    /// Authorization identity (username).
    _authzid = Utils().getBareJIDFromJID(jid);

    /// Authentication identity (user name).
    _authcid = authcid ?? Utils().getNodeFromJID(jid);

    /// Authentication identity. Equal gathered `password` to global password.
    _password = password;

    /// Connection callback will be equal if there is one.
    _connectCallback = (status, [condition, element]) => callback!.call(status);

    /// Make `disconnectin` false.
    _disconnecting = false;

    /// Make `authentication` false.
    _authenticated = false;

    /// Make `connected` false.
    _connected = false;

    /// Make global `disconnectionTimeout` value to be equal to passed one.
    _disconnectionTimeout = disconnectionTimeout;

    /// Parse `jid` for domain.
    _domain = Utils().getDomainFromJID(jid);

    /// Change the status of connection to `connecting`.
    _changeConnectStatus(EchoStatus.connecting, null);

    /// Build connection of the `protocol`.
    _protocol.connect();
  }

  /// Helper function that makes sure plugins and the user's callback are
  /// notified of connection status changes.
  ///
  /// * @param status New connection status, one of the values of [Status] enum.
  /// * @param condition The error condition or null.
  /// * @param element The triggering stanza.
  void _changeConnectStatus(
    /// Status of the connection.
    EchoStatus status,

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
    if (_connectCallback != null) {
      try {
        _connectCallback!.call(status, condition, element);
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
  @protected
  void _xmlInput(dynamic element) {
    if (xmlInput != null) {
      xmlInput?.call(element);
    }
    return;
  }

  /// User overrideable function that receives XML data sent to the connection.
  ///
  /// The default function does nothing. User code can override this with:
  /// ```dart
  /// echo.xmlOutput = (element) {
  ///   /// ...user code
  /// }
  /// ```
  /// * @param element The XMLdata sent by the connection.
  void _xmlOutput(dynamic element) {
    if (xmlOutput != null) {
      xmlOutput?.call(element);
    }
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
  void _rawInput(dynamic data) {
    if (rawInput != null) {
      rawInput?.call(data);
    }
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
  void _rawOutput(dynamic data) {
    if (rawOutput != null) {
      rawOutput?.call(data);
    }
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

  /// Immediately send any pending outgoing data.
  ///
  /// Normally send() queues outgoing data until the next idle period (100ms),
  /// which optimizes network use in the common cases when several send()s are
  /// called in succession. flush() can be used to immediately send all pending
  /// data.
  void flush() {
    /// Cancel current idle timeout.
    _idleTimeout.cancel();

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
      _queueData(message as xml.XmlElement);
    }

    /// Run the protocol send function to flush all the available data.
    _protocol.send();
  }

  /// Queue outgoing data for later sending.
  ///
  /// * @param element dynamic, this can be one
  void _queueData(xml.XmlElement? element) {
    /// Check whether `element` is not null and local name is not empty.
    if (element == null ||
        element.children.isEmpty ||
        element.name.local.isEmpty) {
      /// If one of above conditions are met, then throw an [Exception].
      throw Exception('Cannot queue empty element.');
    }
    _data.add(element);
  }

  /// Send an xmpp:restart stanza.
  void sendRestart() {
    _data.add('restart');
    _protocol.sendRestart();

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
  _TimedHandler addTimedHandler(int period, bool Function() handler) {
    /// Declare new [_TimedHandler] object using passed params.
    final timed = _TimedHandler(period: period, handler: handler);

    /// Add created [_TimedHandler] to `addTimeds` list.
    _addTimeds.add(timed);
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
    _removeTimeds.add(reference);
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
  Handler addHandler({
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
    bool Function([xml.XmlElement?])? handler,
  }) {
    /// Create new [Handler] object.
    final hand = Handler(
      handler: handler,
      name: name,
      namespace: namespace,
      type: type,
      id: id,
      from: from,
      options: options,
    );

    /// Add handlers to the list.
    _addHandlers.add(hand);
    return hand;
  }

  /// Delete a stanza handler for a connection.
  ///
  /// This function removes a stanza handler from the connection. The
  /// `reference` parameter is not the function passed to `addHandler()`,
  /// but is the reference returned from `addHandler()`.
  ///
  /// * @param reference The handler reference.
  void deleteHandler(Handler reference) {
    /// Add [Handler] reference to the list of to be removed handlers.
    ///
    /// This must be done in the Idle loop so that we do not change the
    /// handlers during iteration.
    _removeHandlers.add(reference);

    /// Get the index of handler from the handler list.
    final i = _addHandlers.indexOf(reference);
    if (i >= 0) {
      /// Remove the dedicated handler.
      _addHandlers.removeAt(i);
    }

    return;
  }

  /// Register the SASL mechanisms which will be supported by this instance of
  /// [Echo] (i.e. which this XMPP client will support).
  ///
  /// * @param mechanisms Array of objects which extend [SASL] concrete class.
  void _registerMechanisms() {
    /// Register variable as empty beforehand.
    _mechanisms = {};

    /// The list of all available authentication mechanisms.
    late final mechanismList = <SASL>[
      SASLAnonymous(),
      SASLExternal(),
      SASLOAuthBearer(),
      SASLXOAuth2(),
      SASLPlain(),
      SASLSHA1(),
      SASLSHA256(),
      SASLSHA384(),
      SASLSHA512(),
    ];
    mechanismList.map((mechanism) => _registerSASL(mechanism)).toList();
  }

  /// Register a single [SASL] mechanism, to be supported by this client.
  ///
  /// * @param mechanism SASL type auth object.
  void _registerSASL(SASL mechanism) =>
      _mechanisms![mechanism.name] = mechanism;

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
    _changeConnectStatus(EchoStatus.disconnecting, reason);

    /// Log according to the `reason` value.
    if (reason != null) {
      Log().warn('Disonnect was called because: $reason');
    } else {
      Log().info('Disconnect was called');
    }

    /// Proceed if [Echo] is connected to the server.
    if (_connected) {
      /// Nullable `presence` decleration of the [EchoBuilder] object.
      EchoBuilder? presence;

      /// Change disconnecting flag to `true`.
      _disconnecting = true;

      /// Proceed if user is authenticated.
      if (_authenticated) {
        presence = EchoBuilder.pres(
          attributes: {'xmlns': ns['CLIENT'], 'type': 'unavailable'},
        );
      }

      /// Set timeout handler.
      _disconnectTimeout = _addSystemTimedHandler(
        _disconnectionTimeout,
        _onDisconnectTimeout.call,
      );
      _protocol.abortAllRequests();
      if (presence != null) {
        _protocol.disconnect(presence.nodeTree);
      } else {
        _protocol.disconnect();
      }
    }

    /// Else proceed to this scope.
    else {
      Log().warn('Disconnect was called before Echo connected to the server.');
      _protocol.abortAllRequests();
      _doDisconnect();
    }
  }

  /// Disconnects the XMPP connection.
  ///
  /// This is the last piece of the disconnection logic. This resets the
  /// connection and alerts the user's connection callback.
  ///
  /// It takes an optional [condition] parameter which represents the reason or
  /// condition for disconnecting.
  void _doDisconnect([String? condition]) {
    _idleTimeout.cancel();

    /// If the [_disconnectTimeout] is set, it will be canceled by calling the
    /// [deleteTimedHandler] method with the [_disconnectTimeout] as the argument.
    if (_disconnectTimeout != null) {
      deleteTimedHandler(_disconnectTimeout!);

      /// After removal, make it null like the constructor do in the beginning.
      _disconnectTimeout = null;
    }

    /// Logs the disconnection event.
    Log().log('_doDisconnect was called');

    /// Invokes `doDisconnect` method which is declared as [Protocol] object
    /// method.
    _protocol.doDisconnect();

    /// Resetting internal flags and variables.
    _authenticated = false;
    _disconnecting = false;

    /// Clear Handler holder list.
    _handlers.clear();

    /// Clear handlers list.
    _addHandlers.clear();

    /// Clear handlers list which need to be removed.
    _removeHandlers.clear();

    /// Clear timed handler stored list.
    _timedHandlers.clear();

    /// Clear added timed handlers list.
    _addTimeds.clear();

    /// Clear timed handler stored list for removal.
    _removeTimeds.clear();

    /// Change connection status of the server to disconnecting to indicate that
    /// the process is in the state of disconnecting.
    _changeConnectStatus(EchoStatus.disconnected, condition);

    /// Finally, make connected property false.
    _connected = false;
  }

  /// Handler to processes incoming data from the connection.
  ///
  /// Except for `connectCB` handling the initial connection request,
  /// this function handles the incoming data for all requests. This function
  /// also fires stanza handlers that match each incoming stanza.
  ///
  /// * @param response The response that has data ready
  /// * @param raw The stanza as a raw string (optional)
  void _dataReceived(xml.XmlElement response, [String? raw]) {
    final element = _protocol.reqToData(response);
    if (element == null) return;

    if (element.name.local == _protocol.strip && element.children.isNotEmpty) {
      _xmlInput(element.children[0]);
    } else {
      _xmlInput(element);
    }

    if (raw != null) {
      _rawInput(raw);
    } else {
      _rawInput(Utils.serialize(element));
    }

    /// Remove handlers scheduled for deletion.
    while (_removeHandlers.isNotEmpty) {
      final hand = _removeHandlers.removeLast();
      final i = _handlers.indexOf(hand);
      if (i >= 0) {
        _handlers.removeAt(i);
      }
    }

    /// Add handlers scheduled for deletion.
    while (_addHandlers.isNotEmpty) {
      _handlers.add(_addHandlers.removeLast());
    }

    /// Handle graceful disconnect
    if (_disconnecting) {
      _doDisconnect();
      return;
    }

    final type = element.getAttribute('type');
    if (type != null && type == 'terminate') {
      /// Do not process stanzas that come in after disconnect.
      if (_disconnecting) {
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
        _changeConnectStatus(EchoStatus.connectionFailed, condition);
      } else {
        _changeConnectStatus(
          EchoStatus.connectionFailed,
          errorCondition['UNKNOWN_REASON'],
        );
      }
      _doDisconnect(condition);
      return;
    }

    /// Send each incoming stanza through the handler chain.
    Utils.forEachChild(element, null, (child) {
      final matches = [];
      _handlers = _handlers.where((handler) {
        try {
          if (handler.isMatch(child) && (_authenticated || !handler.user)) {
            if (handler.run(child)!) {
              return true;
            }
            matches.add(handler);
          } else {
            return true;
          }
        } catch (error) {
          /// If the handler throws an exception, we consider it as false.
          ///
          // if the handler throws an exception, we consider it as false
          Log()
              .warn('Removing Echo handlers due to uncaught exception: $error');
        }
        return false;
      }).toList();

      /// If no handler was fired for an incoming IQ with type='set', then we
      /// return an IQ error stanza with `service-unavailable`.
      if (matches.isEmpty && _iqFallbackHandler.isMatch(child)) {
        _iqFallbackHandler.run(child);
      }
    });
  }

  /// Private binding method.
  ///
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
  void _bind() {
    if (!_doBind) {
      Log().info('Echo bind called but "do_bind" is false');
      return;
    }
    _addSystemHandler(
      handler: ([element]) => _onResourceBindResultIQ(element!),
      id: '_bind_auth_2',
    );
    final resource = Utils().getResourceFromJID(jid);
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
  bool _onResourceBindResultIQ(xml.XmlElement element) {
    if (element.getAttribute('type') == 'error') {
      Log().warn('Resource binding failed.');
      final conflict = element.getElement('conflict');
      String? condition;
      if (conflict != null) {
        condition = errorCondition['CONFLICT'];
      }
      _changeConnectStatus(EchoStatus.authenticationFailed, condition, element);
      return false;
    }
    final bind = element.findAllElements('bind').toList();
    if (bind.isNotEmpty) {
      final jidNode = bind[0].findAllElements('jid').toList();
      if (jidNode.isNotEmpty) {
        _authenticated = true;
        jid = Utils.getText(jidNode[0]);
        if (_doSession) {
          _establishSession();
        } else {
          _changeConnectStatus(EchoStatus.connected, null);
        }
      }
    } else {
      Log().warn('Resource binding failed.');
      _changeConnectStatus(EchoStatus.authenticationFailed, null, element);
      return false;
    }
    return false;
  }

  /// Private `connectCB` method.
  ///
  /// SASL authentication will be attempted if available, otherwise the code
  /// will fall back to legaacy authentication.
  ///
  /// * @param request The current request
  /// * @param callback Low level (xmpp) connect callback function.
  void _connectCB(
    xml.XmlElement request,
    void Function(Echo)? callback, [
    String? raw,
  ]) {
    Log().log('connectCB was called');
    _connected = true;

    xml.XmlElement? bodyWrap;
    try {
      bodyWrap = _protocol.reqToData(request);
    } catch (error) {
      _changeConnectStatus(
        EchoStatus.connectionFailed,
        errorCondition['BAD_FORMAT'],
      );
      _doDisconnect(errorCondition['BAD_FORMAT']);
    }

    if (bodyWrap == null) return;
    if (bodyWrap.name.qualified == _protocol.strip &&
        bodyWrap.children.isNotEmpty) {
      _xmlInput(bodyWrap.children.first);
    } else {
      _xmlInput(bodyWrap);
    }

    if (raw != null) {
      _rawInput(raw);
    } else {
      _rawInput(Utils.serialize(bodyWrap));
    }

    final connectionCheck = _protocol.connectCB(bodyWrap);
    if (connectionCheck == status[EchoStatus.connectionFailed]) {
      return;
    }

    /// Check for the stream:features tag
    bool hasFeatures;
    hasFeatures =
        bodyWrap.findAllElements('stream:features').toList().isNotEmpty ||
            bodyWrap.findAllElements('features').toList().isNotEmpty;

    if (!hasFeatures) {
      _protocol.nonAuth(callback);
      return;
    }

    final matched = List.from(bodyWrap.findAllElements('mechanism'))
        .map(
          (mechanism) => _mechanisms![(mechanism as xml.XmlElement).innerText],
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
        _protocol.nonAuth(callback);
        return;
      }
    }
    if (_doAuthentication) _authenticate(matched);
  }

  void _authenticate(List<SASL?> mechanisms) {
    if (!_attemptSASLAuth(mechanisms)) {
      _attemptLegacyAuth();
    }
  }

  /// Sorts a list of objects with prototype SASLMechanism according to their
  /// properties.
  List<SASL?> _sortMechanismsByPriority(List<SASL?> mechanisms) {
    /// Iterate over all the available mechanisms.
    for (int i = 0; i < mechanisms.length - 1; i++) {
      int higher = i;
      for (int j = i + 1; j < mechanisms.length; ++j) {
        if (mechanisms[j]!.priority! > mechanisms[higher]!.priority!) {
          higher = j;
        }
      }
      if (higher != i) {
        final swap = mechanisms[i];
        mechanisms[i] = mechanisms[higher];
        mechanisms[higher] = swap;
      }
    }
    return mechanisms;
  }

  /// Iterate through an array of SASL mechanisms and attempt authentication
  /// with the hightes priority (enabled) mechanism.
  ///
  /// * @param mechanisms List of [SASL] mechanisms.
  /// * @return [bool] true or false, depending on whether a valid SASL
  /// mechanism was found with which authentication could be started.
  bool _attemptSASLAuth(List<SASL?> mechanisms) {
    final mechs = _sortMechanismsByPriority(mechanisms);
    bool mechanismFound = false;
    for (int i = 0; i < mechs.length; i++) {
      mechanisms[i]!.connection = this;
      if (!mechs[i]!.test()) {
        continue;
      }
      _saslSuccessHandler = _addSystemHandler(
        name: 'success',
        handler: ([element]) => _saslSuccessCB(element),
      );
      _saslFailureHandler = _addSystemHandler(
        name: 'failure',
        handler: ([element]) => _saslFailureCB(element),
      );
      _saslChallengeHandler = _addSystemHandler(
        name: 'challenge',
        handler: ([element]) => _saslChallengeCB(element!),
      );

      _mechanism = mechanisms[i];

      final requestAuthExchange = EchoBuilder('auth', {
        'xmlns': ns['SASL'],
        'mechanism': _mechanism!.name,
      });
      if (_mechanism!.isClientFirst!) {
        final response = _mechanism!.clientChallenge();
        requestAuthExchange.t(Utils.btoa(response));
      }
      send(requestAuthExchange.nodeTree);
      mechanismFound = true;
      break;
    }
    return mechanismFound;
  }

  bool _saslChallengeCB(xml.XmlElement element) {
    final challenge = Utils.atob(Utils.getText(element));
    final response = _mechanism?.onChallenge(challenge: challenge);
    final stanza = EchoBuilder('response', {'xmlns': ns['SASL']});
    if (response!.isNotEmpty) {
      stanza.t(Utils.btoa(response));
    }
    send(stanza.nodeTree);

    return true;
  }

  /// Attempt legacy (i.e. non-SASL) authentication.
  void _attemptLegacyAuth() {
    /// Check if node is not null, if null then client disconnects.
    if (Utils().getNodeFromJID(jid) == null) {
      _changeConnectStatus(
        EchoStatus.connectionFailed,
        errorCondition['MISSING_JID_NODE'],
      );
      disconnect(errorCondition['MISSING_JID_NODE']);
    }

    /// Else attempt to authenticate.
    else {
      _changeConnectStatus(EchoStatus.authenticating, null);
      _addSystemHandler(
        handler: ([element]) => _onLegacyAuthIQResult(),
        id: '_auth_1',
      );

      send(
        EchoBuilder.iq(
          attributes: {'type': 'get', 'to': _domain, 'id': '_auth_1'},
        )
            .c('query', attributes: {'xmlns': ns['AUTH']!})
            .c('username')
            .t(Utils().getNodeFromJID(jid)!)
            .nodeTree,
      );
    }
  }

  /// This handler is called in response to the initial <iq type='get'/> for
  /// legacy authentication. It builds an authentication <iq/> and sends it,
  /// creating a handler to handle the result.
  ///
  /// * @param element The stanza that triggered the callback.
  /// * @return false to remove the handler.
  bool _onLegacyAuthIQResult() {
    /// Generate IQ stanza with the id of `_auth_2`.
    final iq = EchoBuilder.iq(
      attributes: {'type': 'set', 'id': '_auth_2'},
    )
        .c('query', attributes: {'xmlns': ns['AUTH']!})
        .c('username')
        .t(Utils().getNodeFromJID(jid)!)
        .up()
        .c('password')
        .t(_password as String);

    if (Utils().getResourceFromJID(jid) == null) {
      /// Since the user has not supplied a resource, we pick a default one
      /// here. Unlike other auth methods, the server cannot do this for us.
      jid = '${Utils().getBareJIDFromJID(jid)}/echo';
    }
    iq.up().c('resource', attributes: {}).t(Utils().getResourceFromJID(jid)!);
    _addSystemHandler(
      handler: ([element]) => _auth2CB(element!),
      id: '_auth_2',
    );
    send(iq.nodeTree);
    return false;
  }

  /// Private handler for successful SASL authentication.
  ///
  /// This function is invoked when the SASL authentication process succeeds.
  /// It performs additional checks on the server signature (if available) and
  /// handles the necessary cleanup and further steps after successful
  /// authentication.
  ///
  /// * @param element The matching stanza.
  /// * @return false to remove the handler.
  bool _saslSuccessCB(xml.XmlElement? element) {
    /// Check server signature (if available). By decoding the success message
    /// and extracting the server signature attribute. If the server signature
    /// is invalid, it invokes the SASL failure callback, cleans up the relevant
    /// handlers, and returns false.
    if (_saslData!['server-signature'] != null) {
      String? serverSignature;
      final success = Utils.btoa(Utils.getText(element!));
      final attribute = RegExp(r'([a-z]+)=([^,]+)(,|$)');
      final matches = attribute.allMatches(success);
      for (final match in matches) {
        if (match.group(1) == 'v') {
          serverSignature = match.group(2);
        }
      }

      /// Check if server signature is valid.
      if (serverSignature != null &&
          serverSignature != _saslData!['server-signature']) {
        /// Remove old handlers
        deleteHandler(_saslFailureHandler!);

        /// Make failure handler null.
        _saslFailureHandler = null;

        /// Cleanup challenge handler.
        if (_saslChallengeHandler != null) {
          deleteHandler(_saslChallengeHandler!);
          _saslChallengeHandler = null;
        }

        /// Clear sasl data.
        _saslData!.clear();
        return _saslFailureCB();
      }
    }

    /// If the server signature is valid, it logs the successful SASL
    /// authentication and invokes the onSuccess callback for the specific SASL
    /// mechanism.
    Log().info('SASL authentication succeed');

    /// Invoke onSuccess callback for the specific mechanism.
    if (_mechanism != null) {
      _mechanism?.onSuccess();
    }

    /// Remove old handlers
    deleteHandler(_saslFailureHandler!);
    _saslFailureHandler = null;
    if (_saslChallengeHandler != null) {
      deleteHandler(_saslChallengeHandler!);
      _saslChallengeHandler = null;
    }
    final streamFeatureHandlers = <Handler>[];

    /// Wrapper function to handle stream features after SASL authentication.
    bool wrapper(List<Handler> handlers, xml.XmlElement element) {
      while (handlers.isNotEmpty) {
        deleteHandler(handlers.removeLast());
      }
      _onStreamFeaturesAfterSASL(element);
      return false;
    }

    /// Add system handlers for stream:features.
    streamFeatureHandlers.add(
      _addSystemHandler(
        handler: ([element]) => wrapper(streamFeatureHandlers, element!),
        name: 'stream:features',
      ),
    );

    /// Add system handlers for features.
    streamFeatureHandlers.add(
      _addSystemHandler(
        handler: ([element]) => wrapper(streamFeatureHandlers, element!),
        namespace: ns['STREAM'],
        name: 'features',
      ),
    );

    /// In the end, must send xmpp:restart
    sendRestart();
    return false;
  }

  bool _onStreamFeaturesAfterSASL(xml.XmlElement element) {
    // _features = element;
    for (int i = 0; i < element.descendantElements.length; i++) {
      final child = element.descendantElements.toList()[i];
      if (child.name.local == 'bind') {
        _doBind = true;
      }
      if (child.name.local == 'session') {
        _doSession = true;
      }
    }
    if (!_doBind) {
      _changeConnectStatus(EchoStatus.authenticationFailed, null);
      return false;
    } else if (options['explicitResourceBinding'] == null ||
        (options['explicitResourceBinding'] as bool) != true) {
      _bind();
    } else {
      _changeConnectStatus(EchoStatus.bindingRequired, null);
    }
    return false;
  }

  /// Send IQ request to establish a session with the XMPP server.
  ///
  /// Note: The protocol for sessoin establishment has been determined as
  /// unnecessary and removed in `RFC-6121`.
  void _establishSession() {
    /// It first checks if `_doSession` is `false`. If it is, it throws an
    /// exception indicating that the session was not advertised by the server.
    if (!_doSession) {
      /// Throw [Exception].
      throw Exception(
        '_establishSession called but apparently ${ns['SESSION']} was not advertised by the server',
      );
    }

    /// Adds a system handler using the `_addSystemHandler` method. The handler
    /// is a function that will be called when the session result is received.
    ///
    /// The function passed to the handler is `_onSessionResultIQ`, which is
    /// responsible for handling the session result.
    _addSystemHandler(
      handler: ([element]) => _onSessionResultIQ(element!),
      id: '_session_auth_2',
    );

    /// Sends an IQ request to the server using the `send` method.
    ///
    /// The IQ request is created using `EchoBuilder.iq` and includes
    /// attributes such as 'type' (set) and 'id' ('_session_auth_2').
    /// The IQ request also includes a 'session' element with the 'xmlns'
    /// attribute set to the value of `urn:ietf:params:xml:ns:xmpp-session`.
    send(
      EchoBuilder.iq(
        attributes: {
          'type': 'set',
          'id': '_session_auth_2',
        },
      ).c('session', attributes: {'xmlns': ns['SESSION']!}).nodeTree,
    );
  }

  /// Private handler for the server's IQ response to a client's session
  /// request.
  ///
  /// This sets `_authenticated` to true on success, which starts the
  /// processing of user handlers.
  ///
  /// Note: The protocol for sessoin establishment has been determined as
  /// unnecessary and removed in `RFC-6121`.
  ///
  /// * @param element The matching stanza.
  /// * @return false to remove the handler.
  bool _onSessionResultIQ(xml.XmlElement element) {
    /// If the 'type' attribute is 'result', it means the session was created
    /// successfully.
    if (element.getAttribute('type') == 'result') {
      /// In this case, the method sets the `_authenticated` variable to `true`.
      _authenticated = true;

      /// The `_changeConnectStatus` method with the parameters
      /// `EchoStatus.connected` and `null` is called.
      _changeConnectStatus(EchoStatus.connected, null);
    }

    /// If the 'type' attribute is 'error', it means the session creation
    /// failed.
    else if (element.getAttribute('type') == 'error') {
      /// The method sets the `_authenticated` variable to `false`.
      _authenticated = false;

      /// Logs a warning message using the `Log().warn` function.
      Log().warn('Session creation failed.');

      /// Calls the `_changeConnectStatus` method with the parameters
      /// `EchoStatus.authenticationFailed`, `null`, and the error element.
      _changeConnectStatus(EchoStatus.authenticationFailed, null, element);

      /// The method returns `false` in both cases, indicating that the session
      /// result was not successfully handled.
      return false;
    }
    return false;
  }

  /// Private handler for SASL authentication failure.
  ///
  /// * @param element XmlElment type matching stanza.
  /// * @return false to remove the handler.
  bool _saslFailureCB([xml.XmlElement? element]) {
    if (_saslChallengeHandler != null) {
      deleteHandler(_saslChallengeHandler!);
      _saslChallengeHandler = null;
    }
    if (_saslSuccessHandler != null) {
      deleteHandler(_saslSuccessHandler!);
      _saslSuccessHandler = null;
    }
    if (_mechanism != null) {
      _mechanism?.onFailure();
    }

    /// Send authentication failed status.
    _changeConnectStatus(EchoStatus.authenticationFailed, null, element);
    return false;
  }

  /// Private handler to finish legacy authentication.
  ///
  /// This handler is called when the result from the `jabber:iq:auth` <iq/>
  /// stanza is returned.
  ///
  /// * @param element The stanza that triggered the callback.
  /// * @return false to remove the handler.
  bool _auth2CB(xml.XmlElement element) {
    if (element.getAttribute('type') == 'result') {
      _authenticated = true;
      _changeConnectStatus(EchoStatus.connected, null);
    } else if (element.getAttribute('type') == 'error') {
      _changeConnectStatus(EchoStatus.authenticationFailed, null, element);
      disconnect('Authenticated failed');
    }
    return false;
  }

  bool _onDisconnectTimeout() {
    return false;
  }

  /// Private handler to process events during idle cycle.
  ///
  /// This handler is called in every 100ms to fire timed handlers that are
  /// ready and keep poll request going.
  void _onIdle() {
    /// Add timed handlers scheduled for addition
    while (_addTimeds.isNotEmpty) {
      _timedHandlers.add(_addTimeds.removeLast());
    }

    /// Remove timed handlers that have been scheduled for removal.
    while (_removeTimeds.isNotEmpty) {
      final handler = _removeTimeds.removeLast();
      final i = _timedHandlers.indexOf(handler);
      if (i >= 0) {
        _timedHandlers.removeAt(i);
      }
    }

    /// Call ready timed handlers
    final now = DateTime.now();
    final newbie = <_TimedHandler>[];
    for (int i = 0; i < _timedHandlers.length; i++) {
      final timed = _timedHandlers[i];
      if (_authenticated || !timed.user) {
        final since = timed.lastCalled!.millisecondsSinceEpoch + timed.period;
        if (since - now.millisecondsSinceEpoch <= 0) {
          if (timed.run()) {
            newbie.add(timed);
          }
        } else {
          newbie.add(timed);
        }
      }
    }
    _timedHandlers = newbie;
    _idleTimeout.cancel();
    _protocol.onIdle();

    /// Reactivate the timer only if connected
    if (_connected) {
      _idleTimeout = Timer(const Duration(milliseconds: 100), () => _onIdle());
    }
  }

  /// Private function to add a system level timed handler.
  ///
  /// This function is used to add [_TimedHandler] for the library code. System
  /// timed handlers are allowed to run before authentication is complete.
  ///
  /// * @param period The period of the handler.
  /// * @param handler The callback function.
  _TimedHandler _addSystemTimedHandler(int period, bool Function() handler) {
    /// Create [_TimedHandler] first, for adding to the created handler list.
    final timed = _TimedHandler(period: period, handler: handler);

    /// Set the user to false.
    timed.user = false;

    /// Add created handler to the list of timed handlers.
    _addTimeds.add(timed);
    return timed;
  }

  /// Private method to add a system level stanza handler.
  ///
  /// This function is used to add [Handler] for the library code. System
  /// stanza handlers are allowed to run before authentication is complete.
  ///
  /// * @param handler The callback function.
  /// * @param namespace The namespace match.
  /// * @param name The stanza name to match.
  /// * @param type The stanza type attribute to match.
  /// * @param id The stanza id attribute to match.
  Handler _addSystemHandler({
    /// The user callback.
    String? namespace,

    /// The namespace to match.
    String? name,

    /// The stanza name to match.
    String? id,

    /// The stanza type.
    dynamic type,

    /// The user callback.
    bool Function([xml.XmlElement?])? handler,
  }) {
    /// Create [Handler] for passing to the system handler list.
    final hand = Handler(
      handler: handler,
      namespace: namespace,
      name: name,
      type: type,
      id: id,
    );

    /// Equal to false for indicating that this is system handler.
    hand.user = false;

    /// Add created [Handler] to the list.
    _addHandlers.add(hand);

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
class Handler {
  Handler({
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
    if (this.options!.containsKey('matchBare')) {
      Log().warn(
        'The "matchBare" option is deprecated, use "matchBareFromJid" instead.',
      );
      this.options!['matchBareFromJid'] = this.options!['matchBareFromJid']!;
      this.options!.remove('matchBare');
    }
    if (this.options!.containsKey('matchBareFromJid')) {
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
  final bool Function([xml.XmlElement? element])? handler;

  /// Retrieves the namespacce of an XML element.
  String? getNamespace(xml.XmlElement element) {
    /// Defaults to the attribute of `xlmns`.
    String? namespace = element.getAttribute('xmlns');

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
      if (getNamespace(node) == namespace) {
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
        (type == null ||
            (type is List
                ? (type! as List).contains(elementType)
                : elementType == type)) &&
        (id == null || element.getAttribute('id') == id) &&
        (this.from == null || from == this.from)) {
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
    } catch (error) {
      return false;
    }
    return result;
  }

  @override
  String toString() =>
      '{Handler: $handler (name: $name, id: $id, namespace: $namespace type: $type options: $options)}';
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
  final bool Function() handler;

  bool user = true;

  /// Nullable param for indicating lastCalled time of the handler.
  DateTime? lastCalled;

  /// Run the callback for the [_TimedHandler].
  ///
  /// * @return `true` if the [_TimedHandler] should be called again, otherwise
  /// false.
  bool run() {
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
