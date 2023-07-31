import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dartz/dartz.dart';

import 'package:echo/extensions/event/event.dart';
import 'package:echo/extensions/extensions.dart';
import 'package:echo/src/builder.dart';
import 'package:echo/src/constants.dart';
import 'package:echo/src/enums.dart';
import 'package:echo/src/exception.dart';
import 'package:echo/src/log.dart';
import 'package:echo/src/protocol.dart';
import 'package:echo/src/sasl.dart';
import 'package:echo/src/utils.dart';

import 'package:web_socket_channel/web_socket_channel.dart' as ws;
import 'package:xml/xml.dart' as xml;

part '../extensions/registration/registration_extension.dart';
part '../extensions/roster/roster_extension.dart';
part '_extension.dart';
part 'bosh.dart';
part 'handler.dart';
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

    /// Defaults to `true`.
    this.debugEnabled = true,

    /// Defaults to `3` seconds.
    this.stanzaResponseTimeout = 3000,
  }) {
    /// Assign passed `debugEnabled` flag to the [Log].
    Log().initialize(debugEnabled: debugEnabled);

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
      (iq) {
        send(
          EchoBuilder.iq(
            attributes: {
              'type': 'error',
              'id': iq.getAttribute('id'),
            },
          ).c('error', attributes: {'type': 'cancel'}).c(
            'service-unavailable',
            attributes: {'xmlns': ns['STANZAS']!},
          ),
        );
        return true;
      },
      stanzaName: 'iq',
      type: ['get', 'set'],
    );

    /// Initialize [DiscoExtension] class and attach to the current [Echo].
    disco = DiscoExtension();
    attachExtension(disco);

    /// Initialize [CapsExtension] class and attach to the current [Echo].
    caps = CapsExtension();
    attachExtension(caps);
  }

  /// `version` constant.
  final String version = '1.0';

  /// The service URL.
  late String service;

  /// Configuration options.
  final Map<String, dynamic> options;

  /// [bool] initializer if there is a need for logging the debug information.
  final bool debugEnabled;

  /// Jabber identifier of the user.
  late String jid;

  /// The timeout duration, representing in milliseconds.
  ///
  /// Indicator for waiting for an incoming stanza response. Used to specify the
  /// maximum amount of time, in milliseconds, to wait for the completion of a
  /// future that is waiting for an incoming stanza response. If the stanza
  /// response does not arrive within this timeout duration, the future will be
  /// considered timed out and an appropriate action can be taken to handle the
  /// timeout.
  late final int stanzaResponseTimeout;

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
  late String? _password;

  /// Values can be either [String] or a [Map].
  late final Map<String, dynamic>? _saslData;

  /// Holds all available mechanisms that are supported by the server.
  Map<String, SASL>? _mechanisms;

  late bool _doAuthentication;
  late bool _authenticated;
  late bool _connected;
  late bool _disconnecting;
  late bool _registering;
  late bool _paused;
  late bool _doBind;
  late bool _doSession;

  /// Used for registration process which is declared using extension list.
  late bool _processedFeatures;

  /// Data holder for sending later on. The data it can hold is can be [String]
  /// or [xml.XmlElement].
  late final List _data = <dynamic>[];

  /// When attached [RegisterExtension] in client, this variable refers to
  /// specific steps or information required for the registration process.
  ///
  /// This can be used by users afterwards to know which fields are required
  /// by the server in order to use `in-band registration` functionality.
  ///
  /// But non-final, cause' it will be initialized later.
  late String registrationInstructions;

  /// In the context of `in-band registration` this variable is the pieces of
  /// information that the XMPP server requires from the user during the
  /// registration process.
  final _fields = <String, String>{};

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

  /// Initialize an empty list of [Extension]s.
  final _extensions = <Extension>[];

  /// Late initialization of [DiscoExtension].
  late final DiscoExtension disco;

  /// Late initialization of [CapsExtension].
  late final CapsExtension caps;

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
  late final FutureOr Function(EchoStatus, [String?, xml.XmlElement?])?
      _onConnectCallback;

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
  void _handleError(dynamic e) {
    Log().trigger(LogType.fatal, e.toString());
  }

  /// Attaches an extension to the current connection.
  ///
  /// The extension is added to the list of attached extensions for this
  /// connection.
  ///
  /// * @param extension The extension to attach to the connection.
  void attachExtension<T>(Extension extension) {
    /// Check if the extension is alrady added. If is is already added, then
    /// warn user about this and do not add again.
    if (_extensions.where((ext) => ext._name == extension._name).isNotEmpty) {
      Log().trigger(
        LogType.warn,
        'The given extension is already attached $extension',
      );
    }

    /// Initialize for the first time.
    extension.initialize(this);

    /// Add to the list of extensions.
    _extensions.add(extension);
  }

  /// Responsible for extending the current namespace in [ns]. It takes a key
  /// and a value with the key being the name of the new namespace.
  ///
  /// ### Usage
  /// final echo = Echo();
  ///
  /// echo.addNamespace(namespace, value);
  void addNamespace(String name, String key) => ns[name] = key;

  /// Select protocol based on `options` or `service`.
  ///
  /// Sets the communication protocol based on the provided options. THis can
  /// be `BOSH` connection (for later updates, not for now), `WebSocket`, or
  /// `WorkerWebSocket` connection.
  void _setProtocol() {
    /// Try to get protocol from `options`, else assign empty string.
    final protocol = options['protocol'] as String? ?? '';

    /// Check if the service is not empty.
    if (service.isEmpty) {
      throw ProtocolException.emptyService();
    }

    /// Check if WebSocket implementation should be used.
    if (service.startsWith('ws:') ||
        service.startsWith('wss:') ||
        protocol.startsWith('ws')) {
      /// Set protocol to [WebSocket].
      _protocol = WebSocket(this);
    }

    /// If not using a WebSocket, check for websocket worker or secure WebSocket
    /// worker service.
    else if (options['worker'] != null && options['worker'] as bool) {
      /// TODO: implement worker web socket.
    } else {
      Log().trigger(LogType.warn, 'No service was found under: $service');
      throw ProtocolException.notDefined(service);
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

    /// Check if extension list contains [RegistrationExtension].
    if (_extensions
        .where((extension) => extension._name == 'registration-extension')
        .isNotEmpty) {
      /// Reset instructions to initial state.
      registrationInstructions = '';

      /// Reset fields variable to its initial state.
      _fields.clear();
    }
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
  /// [Echo] only supports messaging through WebSockets, so if there will be
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
  /// final connection = Echo('wss://example.com:5443/ws');
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

  /// The main function of this package.
  ///
  /// Starts the connection process.
  ///
  /// As the connection process proceeds, the user supplied callback will be
  /// triggered multiple times with the status updates. The callback should take
  /// two arguments - the status code and the error condition.
  ///
  /// * @param jid - The user's JID. This may be a bare JID, or a full JID. If
  /// a node supplied, `SASL OAUTHBEARER` or `SASL ANONYMOUS` authentication
  /// will be attempted (OAUTHBEARER will process the provided password value
  /// as an access token.)
  /// * @param password The user's password. ---->
  ///
  /// (POSTPONED) ------------------------------------------------- (POSTPONED)
  ///
  /// Or an object containing the users
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
  /// (POSTPONED) ------------------------------------------------- (POSTPONED)
  ///
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
  Future<void> connect({
    /// User's `Jabber` identifier.
    required String jid,

    /// The user's password.
    ///
    /// For anonymous logins, this variable will be passed as empty string to
    /// the server.
    String password = '',

    /// The connection callback function.
    FutureOr<void> Function(EchoStatus)? callback,

    /// Optional alternative authentication identifier.
    String? authcid,

    /// Disconnection timeout before terminating.
    int disconnectionTimeout = 3000,
  }) async {
    /// Equal gathered `jid` to global one.
    ///
    /// Authorization identity.
    this.jid = jid;

    /// Authorization identity (username).
    _authzid = Echotils().getBareJIDFromJID(jid);

    /// Authentication identity (user name).
    _authcid = authcid ?? Echotils().getNodeFromJID(jid);

    /// Authentication identity. Equal gathered `password` to global password.
    _password = password;

    if (_extensions
        .where((extension) => extension._name == 'roster-extension')
        .isNotEmpty) {
      final roster = _extensions
          .where((extension) => extension._name == 'roster-extension')
          .first as RosterExtension;

      _onConnectCallback = (status, [condition, element]) async {
        addHandler(roster._onReceivePresence, name: 'presence');
        addHandler(
          roster._onReceiveIQ,
          namespace: ns['ROSTER'],
          name: 'iq',
          type: 'set',
        );

        await callback!.call(status);
      };
    } else {
      /// Connection callback will be equal if there is one.
      _onConnectCallback =
          (status, [condition, element]) async => callback!.call(status);
    }

    /// Make `disconnecting` false initially.
    _disconnecting = false;

    /// Make `authentication` false initially.
    _authenticated = false;

    /// Make `connected` false initially.
    _connected = false;

    /// Make `registering` true initially.
    // _registering = true;

    /// Make global `disconnectionTimeout` value to be equal to passed one.
    _disconnectionTimeout = disconnectionTimeout;

    /// Parse `jid` for domain.
    _domain = Echotils().getDomainFromJID(jid);

    /// Check if [RegistrationExtension] is attached to the client, then
    /// initialize the required variables to its initial values.
    if (_extensions
        .where((extension) => extension._name == 'registration-extension')
        .isNotEmpty) {
      /// Instructions equals to empty string.
      registrationInstructions = '';

      /// Clear fields to return its initial state.
      _fields.clear();

      /// Late initializator of the variable `registering` equals false.
      _registering = true;
    }

    /// Change the status of connection to `connecting`.
    _changeConnectStatus(EchoStatus.connecting, null);

    /// Build connection of the `protocol`.
    await _protocol.connect();
  }

  /// Helper function that makes sure plugins and the user's callback are
  /// notified of connection status changes.
  ///
  /// * @param status New connection status, one of the values of [Status] enum.
  /// * @param condition The error condition or null.
  /// * @param element The triggering stanza.
  Future<void> _changeConnectStatus(
    /// Status of the connection.
    EchoStatus status,

    /// Error condition map value.
    String? condition,

    /// [xml.XmlElement] type element parameter.
    [
    xml.XmlElement? element,
  ]) async {
    if (status == EchoStatus.authenticationFailed) {
      /// Check [AuthenticationFailed] condition. if the condition is true,
      /// then the given message will be printed.
      Log().trigger(
        LogType.warn,
        'Authentication failed. Check the provided credentials or attach RegistrationExtension to register JID',
      );
    }

    /// Checks if there is an implementation of `changeStatus` method in the
    /// given extension list.
    ///
    /// If there is a logic implemented under this method, then it runs the
    /// corresponding method.
    for (final extension in _extensions) {
      try {
        extension.changeStatus(status, condition);
      } on EchoException catch (error) {
        /// If the method is not implemented properly, then it will give info
        /// about the situation.
        Log().trigger(LogType.warn, error.message);
      }
    }

    if (_onConnectCallback != null) {
      try {
        await _onConnectCallback!.call(status, condition, element);
      } catch (error) {
        _handleError(error);
        Log().trigger(
          LogType.error,
          'User connection callback caused an exception: $error',
        );
      }
    }
  }

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
  FutureOr<void> send(
    dynamic message, [
    Completer<Either<xml.XmlElement, EchoException>>? completer,
    FutureOr<void> Function(xml.XmlElement stanza)? resultCallback,
    FutureOr<void> Function(EchoException)? errorCallback,
  ]) async {
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

    /// If `completer` param is not null, then wait for the incoming stanza
    /// result.
    if (completer != null) {
      final either = await completer.future.timeout(
        Duration(milliseconds: stanzaResponseTimeout),
        onTimeout: () => Right(EchoExceptionMapper.requestTimedOut()),
      );

      either.fold(
        (stanza) => resultCallback?.call(stanza),
        (exception) => errorCallback?.call(exception),
      );
    }
  }

  /// Helper function to send IQ stanzas.
  ///
  /// * @param element The stanza to send.
  /// * @param resultCallback The callback function for a successful request.
  /// * @param errorCallback The callback function for a failed or timed out
  /// request.
  /// On timeout, the stanza will be null.
  /// * @param timeout The time specified in milliseconds for a timeout to
  /// occur.
  /// * @param waitForResult A flag indicating whether the handler should wait
  /// for the result of incoming stanza. If this `waitForResult` is set to
  /// `true`, the handler will block and wait for the response of the incoming
  /// stanzas before proceeding.
  FutureOr<void> sendIQ({
    required xml.XmlElement element,
    FutureOr<void> Function(xml.XmlElement element)? resultCallback,
    FutureOr<void> Function(EchoException exception)? errorCallback,
    int? timeout,
    bool waitForResult = false,
  }) async {
    _TimedHandler? timeoutHandler;
    String? id = element.getAttribute('id');
    if (id == null) {
      id = getUniqueId('sendIQ');
      element.setAttribute('id', id);
    }

    /// [Completer] depending on `waitForResult` boolean. If the flag is true,
    /// then completer variable will be used. This completer is used to wait
    /// for the incoming stanza.
    ///
    /// It can return [Either] XmlElement or Exception.
    Completer<Either<xml.XmlElement, EchoException>>? completer;

    /// If the result is waited, then completer equals to an object.
    if (waitForResult) {
      /// Create completer for waiting for stanzas.
      completer = Completer<Either<xml.XmlElement, EchoException>>();
    }

    final handler = addHandler(
      (stanza) {
        if (timeoutHandler != null) {
          deleteTimedHandler(timeoutHandler);
        }
        // final iqType = stanza.getAttribute('type');
        // if (iqType != 'result' || iqType != 'error') {
        //   throw Exception('Got bad IQ type of $iqType');
        // }
        return true;
      },
      resultCallback: resultCallback,
      errorCallback: errorCallback,
      name: 'iq',
      id: id,
      type: ['result', 'error'],
      completer: completer,
    );

    /// If timeout specified, set up a timeout handler.
    if (timeout != null) {
      timeoutHandler = addTimedHandler(timeout, () {
        /// Get rid of normal handler.
        deleteHandler(handler);

        return false;
      });
    }

    send(element);

    /// If the completer is not null, that means the user wants to wait for
    /// waiting stanzas.
    if (completer != null) {
      /// Wait for the future of completer.
      final either = await completer.future.timeout(
        Duration(milliseconds: stanzaResponseTimeout),
        onTimeout: () => Right(EchoExceptionMapper.requestTimedOut()),
      );

      either.fold(
        (stanza) => resultCallback?.call(stanza),
        (exception) => errorCallback?.call(exception),
      );
    }
  }

  /// Queue outgoing data for later sending.
  ///
  /// * @param element dynamic, this can be one
  void _queueData(xml.XmlElement? element) {
    /// Check if `xmlns` contains the given xmlns attribute, if yes, then
    /// queue data without check.
    if (element != null && element.getAttribute('xmlns') == ns['CLIENT']) {
      _data.add(element);
      return;
    }

    /// Check whether `element` is not null and local name is not empty.
    if (element == null ||
        element.children.isEmpty ||
        element.name.local.isEmpty) {
      /// If one of above conditions are met, then throw an [Exception].
      throw Exception('Cannot queue empty element');
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
  /// * @param resultCallback The user callback when incoming stanza is
  /// `result`.
  /// * @param errorCallback The user callback for when incoming stanza contains
  /// error.
  /// * @param namespace The namespace to match.
  /// * @param name The stanza name to match.
  /// * @param type The stanza type (or types if an array) to match. This can be
  /// [String] or [List].
  /// * @param id The stanza id attribute to match.
  /// * @param from The stanza from attribute to match.
  /// * @param options The handler options
  /// * @param completer Provides a way to produce a single value in the future,
  /// either with a successful result represented by an [XmlElement] or an error
  /// represented by an [EchoException].
  /// * @return A reference to the handler that can be used to remove it.
  Handler addHandler(
    /// The user callback.
    FutureOr<bool> Function(xml.XmlElement)? handler, {
    /// The function to handle the XMPP `result` stanzas.
    FutureOr<void> Function(xml.XmlElement)? resultCallback,

    /// The function to handle the XMPP `error` stanzas.
    FutureOr<void> Function(EchoException)? errorCallback,

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

    /// A [Completer] object used to wait for incoming stanzas and complete
    /// with either an [XmlElement] or an [EchoException].
    Completer<Either<xml.XmlElement, EchoException>>? completer,
  }) {
    /// Nullable [Handler] object for creating [Handler] with or without
    /// `completer` parameter.
    Handler? hand;

    if (completer != null) {
      /// Create new [Handler] object.
      hand = Handler(
        handler,
        stanzaName: name,
        namespace: namespace,
        type: type,
        id: id,
        from: from,
        completer: completer,
        options: options,
      );
    } else {
      /// Create new [Handler] object.
      hand = Handler(
        handler,
        stanzaName: name,
        namespace: namespace,
        type: type,
        id: id,
        from: from,
        options: options,
      );

      /// When `fire` is triggered from the [Handler] class which extends [Event]
      /// this method will be triggered and run what is passed to the function.
      hand.event.addListener((either) {
        either.fold(
          (stanza) => resultCallback?.call(stanza),
          (exception) => errorCallback?.call(exception),
        );
      });
    }

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
  Future<void> disconnect(String? reason) async {
    /// Change the status of connection to disconnecting.
    await _changeConnectStatus(EchoStatus.disconnecting, reason);

    /// Log according to the `reason` value.
    if (reason != null) {
      Log().trigger(
        LogType.warn,
        'disconnect method was called because: $reason',
      );
    } else {
      Log().trigger(LogType.info, 'disconnect method was called');
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
        await _protocol.disconnect();
      }
    }

    /// Else proceed to this scope.
    else {
      Log().trigger(
        LogType.warn,
        'Disconnect was called before Echo connected to the server',
      );
      _protocol.abortAllRequests();
      await _doDisconnect();
    }
  }

  /// Disconnects the XMPP connection.
  ///
  /// This is the last piece of the disconnection logic. This resets the
  /// connection and alerts the user's connection callback.
  ///
  /// It takes an optional [condition] parameter which represents the reason or
  /// condition for disconnecting.
  Future<void> _doDisconnect([String? condition]) async {
    _idleTimeout.cancel();

    /// If the [_disconnectTimeout] is set, it will be canceled by calling the
    /// [deleteTimedHandler] method with the [_disconnectTimeout] as the argument.
    if (_disconnectTimeout != null) {
      deleteTimedHandler(_disconnectTimeout!);

      /// After removal, make it null like the constructor do in the beginning.
      _disconnectTimeout = null;
    }

    /// Logs the disconnection event.
    Log().trigger(LogType.info, 'doDisconnect method was called');

    /// Invokes `doDisconnect` method which is declared as [Protocol] object
    /// method.
    await _protocol.doDisconnect();

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
    await _changeConnectStatus(EchoStatus.disconnected, condition);

    /// Finally, make connected property false.
    _connected = false;
  }

  /// Handler to processes incoming data from the connection.
  ///
  /// Except for `connectCallback` handling the initial connection request,
  /// this function handles the incoming data for all requests. This function
  /// also fires stanza handlers that match each incoming stanza.
  ///
  /// * @param response The response that has data ready
  /// * @param raw The stanza as a raw string (optional)
  Future<void> _dataReceived(xml.XmlElement response, [String? raw]) async {
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
      _rawInput(Echotils.serialize(element));
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
      await _doDisconnect();
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
        await _changeConnectStatus(EchoStatus.connectionFailed, condition);
      } else {
        await _changeConnectStatus(
          EchoStatus.connectionFailed,
          errorCondition['UNKNOWN_REASON'],
        );
      }
      await _doDisconnect(condition);
      return;
    }

    /// Send each incoming stanza through the handler chain.
    Echotils.forEachChild(element, null, (child) async {
      final matches = <Handler>[];
      final handlers = <Handler>[];
      for (final handler in _handlers) {
        try {
          if (handler.isMatch(child) && (_authenticated || !handler.user)) {
            if (await handler.run(child)!) {
              handlers.add(handler);
            }
            matches.add(handler);
          } else {
            handlers.add(handler);
          }
        } catch (error) {
          /// If the handler throws an exception, we consider it as false.
          ///
          // if the handler throws an exception, we consider it as false
          Log().trigger(
            LogType.warn,
            'Removing Echo handlers due to uncaught exception: $error',
          );
        }
      }

      /// Assign new handlers to embbedded one.
      _handlers = handlers;

      /// If no handler was fired for an incoming IQ with type='set', then we
      /// return an IQ error stanza with `service-unavailable`.
      if (matches.isEmpty && _iqFallbackHandler.isMatch(child)) {
        await _iqFallbackHandler.run(child);
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
      Log().trigger(LogType.info, 'Echo bind called but "do_bind" is false');
      return;
    }
    _addSystemHandler(
      (element) async => _onResourceBindResultIQ(element),
      id: '_bind_auth_2',
    );
    final resource = Echotils().getResourceFromJID(jid);
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
  Future<bool> _onResourceBindResultIQ(xml.XmlElement element) async {
    if (element.getAttribute('type') == 'error') {
      Log().trigger(LogType.warn, 'Resource binding failed');
      final conflict = element.getElement('conflict');
      String? condition;
      if (conflict != null) {
        condition = errorCondition['CONFLICT'];
      }
      await _changeConnectStatus(
        EchoStatus.authenticationFailed,
        condition,
        element,
      );
      return false;
    }
    final bind = element.findAllElements('bind').toList();
    if (bind.isNotEmpty) {
      final jidNode = bind[0].findAllElements('jid').toList();
      if (jidNode.isNotEmpty) {
        _authenticated = true;
        jid = Echotils.getText(jidNode[0]);
        if (_doSession) {
          await _establishSession();
        } else {
          await _changeConnectStatus(EchoStatus.connected, null);
        }
      }
    } else {
      Log().trigger(LogType.warn, 'Resource binding failed');
      await _changeConnectStatus(
        EchoStatus.authenticationFailed,
        null,
        element,
      );
      return false;
    }
    return false;
  }

  /// Private `connectCallback` method.
  ///
  /// SASL authentication will be attempted if available, otherwise the code
  /// will fall back to legacy authentication.
  ///
  /// * @param request The current request
  /// * @param callback Low level (xmpp) connect callback function.
  Future<void> _connectCallback(
    xml.XmlElement request,
    Future<void> Function(Echo)? callback, [
    String? raw,
  ]) async {
    Log().trigger(LogType.verbose, 'connectCallback method was called');
    _connected = true;

    xml.XmlElement? bodyWrap;

    /// Check list of extensions which are stacked under the list named
    /// `_extensions`. If `register` extension is implemented, then process
    /// the registration process.
    if (_extensions
        .where((extension) => extension._name == 'registration-extension')
        .isNotEmpty) {
      if (!_registering) {
        if (_processedFeatures) {
          _processedFeatures = false;
        } else {
          _connectCallback(request, callback, raw);
        }
      } else {
        if (await _registerCallback(request, callback, raw)) {
          _processedFeatures = true;
          _registering = false;
        }
        return;
      }
    }

    /// For now, try-catch block does not mean anything to implement due only
    /// `WebSocket` connection is available.
    // try {
    bodyWrap = _protocol.reqToData(request);
    // } catch (error) {
    //   await _changeConnectStatus(
    //     EchoStatus.connectionFailed,
    //     errorCondition['BAD_FORMAT'],
    //   );
    //   await _doDisconnect(errorCondition['BAD_FORMAT']);
    // }

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
      _rawInput(Echotils.serialize(bodyWrap));
    }

    final connectionCheck = await _protocol.connectCallback(bodyWrap);
    if (connectionCheck == status[EchoStatus.connectionFailed]) {
      return;
    }

    /// Check for the stream:features tag
    bool hasFeatures;
    hasFeatures =
        bodyWrap.findAllElements('stream:features').toList().isNotEmpty ||
            bodyWrap.findAllElements('features').toList().isNotEmpty;

    if (!hasFeatures) {
      await _protocol.nonAuth(callback);
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
        await _protocol.nonAuth(callback);
        return;
      }
    }

    if (_doAuthentication) await _authenticate(matched);
  }

  /// Is used internally to handle the registration process by processing the
  /// response stanza received from the server after sending initial
  /// connection IQ request.
  ///
  /// * @param stanza Represents the response stanza received from the initial
  /// IQ request.
  /// * @param callback An optional callback function that will be used in the
  /// case where non-authenticated data is received in the response. If present,
  /// this callback will be executed.
  /// * @param raw An optional [String] representing the raw XML data of the
  /// response stanza. If provided, this raw data will be used in processing the
  /// response.
  Future<bool> _registerCallback(
    xml.XmlElement stanza,
    Future<void> Function(Echo)? callback, [
    String? raw,
  ]) async {
    Log().trigger(LogType.info, 'registerCallback method was called');
    _connected = true;

    final bodyWrap = _protocol.reqToData(stanza);
    if (bodyWrap == null) {
      return false;
    }

    if (bodyWrap.name.qualified == _protocol.strip &&
        bodyWrap.children.isNotEmpty) {
      _xmlInput(bodyWrap.children.first);
    } else {
      _xmlInput(bodyWrap);
    }

    if (raw != null) {
      _rawInput(raw);
    } else {
      _rawInput(Echotils.serialize(bodyWrap));
    }

    final connectionCheck = await _protocol.connectCallback(bodyWrap);
    if (connectionCheck == status[EchoStatus.connectionFailed]) {
      return false;
    }

    final register = bodyWrap.findAllElements('register');
    final mechanisms = bodyWrap.findAllElements('mechanism');
    if (register.isEmpty && mechanisms.isEmpty) {
      _protocol.nonAuth(callback);
      return false;
    }

    if (register.isEmpty) {
      _changeConnectStatus(EchoStatus.registrationFailed, null);
      return true;
    }

    _addSystemHandler(_getRegisterCallback, name: 'iq');

    /// Send initial registration IQ stanza to the server.
    sendIQ(
      element: EchoBuilder.iq(attributes: {'type': 'get'})
          .c('query', attributes: {'xmlns': ns['REGISTER']!}).nodeTree!,
    );

    return true;
  }

  /// In this method, the received stanza is searched for a `query` element,
  /// and the registration fields and instructions are extracted from the
  /// `query` element. The `registrationInstructions` and registration fields
  /// are updated accordingly.
  ///
  /// If the `username` or `password` fields are empty, the method populates
  /// them with appropriate values from the internal `_fields` or `_password`
  /// variables, respectively.
  bool _getRegisterCallback(xml.XmlElement stanza) {
    final query = stanza.findElements('query');

    if (query.isEmpty) {
      _changeConnectStatus(EchoStatus.registrationFailed, null);
      return false;
    }

    for (int i = 0; i < query.first.descendantElements.length; i++) {
      final field = query.first.descendantElements.toList()[i];
      if (field.name.local.toLowerCase() == 'instructions') {
        registrationInstructions = Echotils.getText(field);
      }
      _fields[field.name.local] = Echotils.getText(field);
    }

    if (_fields.containsKey('username')) {
      if (_fields['username']!.isEmpty) {
        _fields['username'] = Echotils().getNodeFromJID(jid)!;
      }
    }

    if (_fields.containsKey('password')) {
      if (_fields['password']!.isEmpty) {
        _fields['password'] = _password!;
      }
    }

    /// Finally, the connection status is updated to 'EchoStatus.register',
    /// indicating that the user data can be `submit`ted.
    _changeConnectStatus(EchoStatus.register, null);
    return false;
  }

  Future<void> _authenticate(List<SASL?> mechanisms) async {
    if (!await _attemptSASLAuth(mechanisms)) {
      await _attemptLegacyAuth();
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
  Future<bool> _attemptSASLAuth(List<SASL?> mechanisms) async {
    final mechs = _sortMechanismsByPriority(mechanisms);
    bool mechanismFound = false;
    for (int i = 0; i < mechs.length; i++) {
      mechanisms[i]!.connection = this;
      if (!mechs[i]!.test()) {
        continue;
      }
      _saslSuccessHandler = await _addSystemHandler(
        (element) => _saslSuccessCallback(element),
        name: 'success',
      );
      _saslFailureHandler = await _addSystemHandler(
        (element) => _saslFailureCallback(element),
        name: 'failure',
      );
      _saslChallengeHandler = await _addSystemHandler(
        (element) => _saslChallengeCallback(element),
        name: 'challenge',
      );

      _mechanism = mechanisms[i];

      final requestAuthExchange = EchoBuilder('auth', {
        'xmlns': ns['SASL'],
        'mechanism': _mechanism!.name,
      });
      if (_mechanism!.isClientFirst!) {
        final response = _mechanism!.clientChallenge();
        requestAuthExchange.t(Echotils.btoa(response));
      }
      send(requestAuthExchange.nodeTree);
      mechanismFound = true;
      break;
    }
    return mechanismFound;
  }

  bool _saslChallengeCallback(xml.XmlElement element) {
    final challenge = Echotils.atob(Echotils.getText(element));
    final response = _mechanism?.onChallenge(challenge: challenge);
    final stanza = EchoBuilder('response', {'xmlns': ns['SASL']});
    if (response!.isNotEmpty) {
      stanza.t(Echotils.btoa(response));
    }
    send(stanza.nodeTree);

    return true;
  }

  /// Attempt legacy (i.e. non-SASL) authentication.
  Future<void> _attemptLegacyAuth() async {
    /// Check if node is not null, if null then client disconnects.
    if (Echotils().getNodeFromJID(jid) == null) {
      await _changeConnectStatus(
        EchoStatus.connectionFailed,
        errorCondition['MISSING_JID_NODE'],
      );
      await disconnect(errorCondition['MISSING_JID_NODE']);
    }

    /// Else attempt to authenticate.
    else {
      await _changeConnectStatus(EchoStatus.authenticating, null);
      _addSystemHandler(
        (element) async => _onLegacyAuthIQResult(),
        id: '_auth_1',
      );

      send(
        EchoBuilder.iq(
          attributes: {'type': 'get', 'to': _domain, 'id': '_auth_1'},
        )
            .c('query', attributes: {'xmlns': ns['AUTH']!})
            .c('username')
            .t(Echotils().getNodeFromJID(jid) ?? '')
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
        .t(Echotils().getNodeFromJID(jid)!)
        .up()
        .c('password')
        .t(_password!);

    if (Echotils().getResourceFromJID(jid) == null) {
      /// Since the user has not supplied a resource, we pick a default one
      /// here. Unlike other auth methods, the server cannot do this for us.
      jid = '${Echotils().getBareJIDFromJID(jid)}/echo';
    }
    iq
        .up()
        .c('resource', attributes: {}).t(Echotils().getResourceFromJID(jid)!);
    _addSystemHandler(
      (element) async => _auth2Callback(element),
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
  Future<bool> _saslSuccessCallback(xml.XmlElement? element) async {
    /// Check server signature (if available). By decoding the success message
    /// and extracting the server signature attribute. If the server signature
    /// is invalid, it invokes the SASL failure callback, cleans up the relevant
    /// handlers, and returns false.
    if (_saslData!['server-signature'] != null) {
      String? serverSignature;
      final success = Echotils.btoa(Echotils.getText(element!));
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
        return _saslFailureCallback();
      }
    }

    /// If the server signature is valid, it logs the successful SASL
    /// authentication and invokes the onSuccess callback for the specific SASL
    /// mechanism.
    Log().trigger(LogType.info, 'SASL authentication succeeded');

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
    Future<bool> wrapper(List<Handler> handlers, xml.XmlElement element) async {
      while (handlers.isNotEmpty) {
        deleteHandler(handlers.removeLast());
      }
      await _onStreamFeaturesAfterSASL(element);
      return false;
    }

    /// Add system handlers for stream:features.
    streamFeatureHandlers.add(
      await _addSystemHandler(
        (element) => wrapper(streamFeatureHandlers, element),
        name: 'stream:features',
      ),
    );

    /// Add system handlers for features.
    streamFeatureHandlers.add(
      await _addSystemHandler(
        (element) => wrapper(streamFeatureHandlers, element),
        namespace: ns['STREAM'],
        name: 'features',
      ),
    );

    /// In the end, must send xmpp:restart
    sendRestart();
    return false;
  }

  Future<bool> _onStreamFeaturesAfterSASL(xml.XmlElement element) async {
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
      await _changeConnectStatus(EchoStatus.authenticationFailed, null);
      return false;
    } else if (options['explicitResourceBinding'] == null ||
        (options['explicitResourceBinding'] as bool) != true) {
      _bind();
    } else {
      await _changeConnectStatus(EchoStatus.bindingRequired, null);
    }
    return false;
  }

  /// Send IQ request to establish a session with the XMPP server.
  ///
  /// Note: The protocol for sessoin establishment has been determined as
  /// unnecessary and removed in `RFC-6121`.
  Future<void> _establishSession() async {
    /// It first checks if `_doSession` is `false`. If it is, it throws an
    /// exception indicating that the session was not advertised by the server.
    if (!_doSession) {
      Log().trigger(
        LogType.warn,
        'establishSession method was called but apparently ${ns['SESSION']} was not advertised by the server',
      );
      return;
    }

    /// Adds a system handler using the `_addSystemHandler` method. The handler
    /// is a function that will be called when the session result is received.
    ///
    /// The function passed to the handler is `_onSessionResultIQ`, which is
    /// responsible for handling the session result.
    _addSystemHandler(
      (element) async => _onSessionResultIQ(element),
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
  Future<bool> _onSessionResultIQ(xml.XmlElement element) async {
    /// If the 'type' attribute is 'result', it means the session was created
    /// successfully.
    if (element.getAttribute('type') == 'result') {
      /// In this case, the method sets the `_authenticated` variable to `true`.
      _authenticated = true;

      /// The `_changeConnectStatus` method with the parameters
      /// `EchoStatus.connected` and `null` is called.
      await _changeConnectStatus(EchoStatus.connected, null);
    }

    /// If the 'type' attribute is 'error', it means the session creation
    /// failed.
    else if (element.getAttribute('type') == 'error') {
      /// The method sets the `_authenticated` variable to `false`.
      _authenticated = false;

      /// Logs a warning message using the `Log().warn` function.
      Log().trigger(LogType.warn, 'Session creation failed');

      /// Calls the `_changeConnectStatus` method with the parameters
      /// `EchoStatus.authenticationFailed`, `null`, and the error element.
      await _changeConnectStatus(
        EchoStatus.authenticationFailed,
        null,
        element,
      );
      _doDisconnect();

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
  Future<bool> _saslFailureCallback([xml.XmlElement? element]) async {
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
    await _changeConnectStatus(EchoStatus.authenticationFailed, null, element);
    await _doDisconnect();
    return false;
  }

  /// Private handler to finish legacy authentication.
  ///
  /// This handler is called when the result from the `jabber:iq:auth` <iq/>
  /// stanza is returned.
  ///
  /// * @param element The stanza that triggered the callback.
  /// * @return false to remove the handler.
  Future<bool> _auth2Callback(xml.XmlElement element) async {
    if (element.getAttribute('type') == 'result') {
      _authenticated = true;
      await _changeConnectStatus(EchoStatus.connected, null);
    } else if (element.getAttribute('type') == 'error') {
      await _changeConnectStatus(
        EchoStatus.authenticationFailed,
        null,
        element,
      );
      await disconnect('Authenticated failed');
    }
    return false;
  }

  bool _onDisconnectTimeout() {
    Log().trigger(LogType.info, 'onDisconnectTimeout method was called');
    _changeConnectStatus(EchoStatus.connectionTimeout, null);
    _doDisconnect();
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
  /// * @param completer Provides a way to produce a single value in the future,
  /// either with a successful result represented by an [XmlElement] or an error
  /// represented by an [EchoException].
  FutureOr<Handler> _addSystemHandler(
    /// The user callback.
    FutureOr<bool> Function(xml.XmlElement) handler, {
    /// The user callback when incoming stanza is `result`. Defaults to `null`.
    FutureOr<void> Function(xml.XmlElement)? resultCallback,

    /// The user callback when incoming stanza is `error`. Defaults to `null`.
    FutureOr<void> Function(EchoException)? errorCallback,

    /// The user callback.
    String? namespace,

    /// The namespace to match.
    String? name,

    /// The stanza name to match.
    String? id,

    /// A [Completer] object used to wait for incoming stanzas and complete
    /// with either an [XmlElement] or an [EchoException].
    Completer<Either<xml.XmlElement, EchoException>>? completer,

    /// The stanza type.
    dynamic type,
  }) async {
    /// Nullable [Handler] object for creating [Handler] with or without
    /// `completer` parameter.
    Handler? hand;

    if (completer != null) {
      /// Create [Handler] for passing to the system handler list.
      hand = Handler(
        handler,
        namespace: namespace,
        stanzaName: name,
        type: type,
        id: id,
        completer: completer,
      );
    } else {
      /// Create [Handler] for passing to the system handler list.
      hand = Handler(
        handler,
        namespace: namespace,
        stanzaName: name,
        type: type,
        id: id,
      );

      /// When `fire` is triggered from the [Handler] class which extends [Event]
      /// this method will be triggered and run what is passed to the function.
      hand.event.addListener(
        (either) => either.fold(
          (stanza) => resultCallback?.call(stanza),
          (exception) => errorCallback?.call(exception),
        ),
      );
    }

    /// Equal to false for indicating that this is system handler.
    hand.user = false;

    /// Add created [Handler] to the list.
    _addHandlers.add(hand);

    return hand;
  }
}
