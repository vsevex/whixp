// import 'dart:async';

// import 'dart:convert';
// import 'dart:math' as math;
// import 'dart:typed_data';

// import 'package:crypto/crypto.dart' as crypto;

// import 'package:echox/src/builder.dart';
// import 'package:echox/src/echotils/echotils.dart';
// import 'package:echox/src/error/error.dart';
// import 'package:echox/src/jid/jid.dart';
// import 'package:echox/src/mishaps.dart';
// import 'package:events_emitter/events_emitter.dart';

// import 'package:web_socket_client/web_socket_client.dart' as ws;
// import 'package:xml/xml.dart' as xml;

// part '_extension.dart';
// part 'handler.dart';
// // part 'sasl/sasl_anon.dart';
// // part 'sasl/sasl_external.dart';
// // part 'sasl/sasl_oauthbearer.dart';
// // part 'sasl/sasl_plain.dart';
// // part 'sasl/sasl_sha1.dart';
// // part 'sasl/sasl_sha256.dart';
// // part 'sasl/sasl_sha384.dart';
// // part 'sasl/sasl_sha512.dart';
// // part 'sasl/sasl_xoauth2.dart';
// // part 'scram.dart';
// part 'websocket.dart';

// /// Serves as the foundation for establishing and managing XMPP (Extensible
// /// Messaging and Presence Protocol) connections. It extends the [EventEmitter]
// /// class, allowing to interact with and respond to various events that occur
// /// during the XMPP communication lifecycle.
// ///
// /// **Key Features**
// ///
// /// - **Event-Driven**: Utilize event listeners to respond to XMPP events such
// ///   as message reception, presence updates, and connection status changes.
// ///
// /// - **Flexible Configuration**: Configure the XMPP connection with custom
// ///   settings and options to meet your application's requirements.
// ///
// /// - **Authentication**: Implement authentication mechanisms and handle user
// ///   authorization seamlessly.
// ///
// /// - **Message Handling**: Send and receive XMPP messages and stanzas with ease.
// ///
// /// - **Presence Management**: Monitor and manage the online presence of users.
// ///
// /// **Note**: The [EchoX] class is designed to be extended and customized for
// /// specific XMPP applications, providing a robust foundation for XMPP
// /// communication.
// ///
// /// ```dart
// /// final jid = JabberID('user@example.com');
// /// final echox = EchoX(jid);
// ///
// /// echox.on<StatusEmitter>('status', (status) {
// ///   if (status.status == EchoStatus.connected) {
// ///     // XMPP connection is established.
// ///   }
// /// });
// ///
// /// echox.connect();
// /// ```
// ///
// /// See also:
// ///
// /// - [EventEmitter], the base class for event-driven functionality.
// /// - [JabberID], the class representing Jabber IDs used for XMPP communication.
// class EchoX extends EventEmitter {
//   /// The [EchoX] class represents an XMPP client connection.
//   ///
//   /// It provides functionality for establishing a connection, handling
//   /// protocols, authentication and managing XMPP stanzas.
//   EchoX({
//     /// Jabber ID.
//     required this.jid,

//     /// The XMPP service URL.
//     required String service,
//     String? password,

//     /// The maximum number of reconnection attempts for a WebSocket.
//     int maxReconnectionAttempts = 3,

//     /// Optional configuration options.
//     Map<String, String>? options,
//   }) {
//     /// The JIDs domain
//     _domain = null;

//     /// Equal the passed params to the private ones.
//     _service = service;
//     _password = password;
//     _options = options ?? {};
//     _maxReconnectionAttempts = maxReconnectionAttempts;

//     /// stream:features
//     features = null;

//     /// SASL
//     _saslData = {};

//     /// Equals to null.
//     _disconnectTimeout = null;

//     /// Equal to empty map.
//     // _mechanisms = {};

//     /// Allows to make authentation.
//     _doAuthentication = true;

//     /// Initial value for `paused` is false.
//     _paused = false;

//     /// Call onIdle callback every 1/10th of a second.
//     _idleTimeout =
//         Timer.periodic(const Duration(milliseconds: 100), (_) => _onIdle);

//     /// Sets the communication protocol based on the provided options.
//     _setProtocol();

//     /// Initialize the start point.
//     reset();

//     /// Register all available [SASL] auth mechanisms.
//     _registerMechanisms();

//     /// A client must always respond to incoming IQ 'set' or 'get' stanzas.
//     ///
//     /// This is a fallback handler which gets called when no other handler was
//     /// called for a received IQ 'set' or 'get'.
//     _iqFallbackHandler = Handler(
//       (iq) {
//         send(
//           EchoBuilder.iq(
//             attributes: {
//               'type': 'error',
//               'id': iq.getAttribute('id')!,
//             },
//           ).c('error', attributes: {'type': 'cancel'}).c(
//             'service-unavailable',
//             attributes: {'xmlns': Echotils.getNamespace('STANZAS')},
//           ),
//         );
//         return true;
//       },
//       name: 'iq',
//       type: ['get', 'set'],
//     );

//     /// Controller for the 'status' stream.
//     final statusController = StreamController<StatusEmitter>();
//     status = statusController.stream;

//     /// Listen for 'status' events and add them to the 'status' stream.
//     on<StatusEmitter>('status', (status) => statusController.sink.add(status));

//     /// Controller for the 'error' stream.
//     final errorController = StreamController<Mishap>();
//     error = errorController.stream;

//     /// Listen for 'error' events and add them to the 'error' stream.
//     on<Mishap>('error', (error) => errorController.sink.add(error));
//   }

//   /// The Jabber ID (JID) representing the essential connection parameter.
//   ///
//   /// The [jid] variable is used to store a Jabber ID (JID), which is a crucial
//   /// connection parameter required for establishing communication with a
//   /// Jabber/XMPP server.
//   late JabberID jid;

//   /// A stream of 'status' events emitted by the [EchoX].
//   ///
//   /// Represents a Stream of 'status' events that can be listened to for updates
//   /// on the status of the EchoX class. 'Status' events typically indicate
//   /// changes in the connection status.
//   late final Stream<StatusEmitter> status;

//   /// A stream of 'error' events emitted by the [EchoX].
//   ///
//   /// Represents a Stream of 'error' events that can be listened to for updates
//   /// on the errors of the EchoX class.
//   late final Stream<Mishap> error;

//   /// The service URL.
//   late String _service;

//   /// Configuration options.
//   late Map<String, String> _options;

//   /// The maximum number of reconnection attempts for a WebSocket.
//   ///
//   /// The [maxReconnectionAttempts] variable represents the maximum number of
//   /// attempts that will be made to reconnect a WebSocket to a server in case of
//   /// disconnection. When the WebSocket connection is lost, the reconnection
//   /// mechanism will make up to [maxReconnectionAttempts] consecutive attempts
//   /// to re-establish the connection before giving up.
//   late int _maxReconnectionAttempts;

//   /// Domain part of the given JID.
//   String? _domain;

//   /// Used to store an XML element that represents various XMPP features
//   /// negotiated during the XMPP session establishment.
//   ///
//   /// These features typically include authentication mechanisms, compression,
//   /// and other capabilities supported by the XMPP server.
//   late xml.XmlElement? features;

//   /// [Protocol] which will be responsible for keeping the type of connection.
//   late WebSocketProtocol _transport;

//   /// Timeout for indicating when the service need to disconnect. Representing
//   /// in milliseconds.
//   late int _disconnectionTimeout;

//   /// Disconnect timeout in the type of [_TimedHandler].
//   _TimedHandler? _disconnectTimeout;

//   /// Authentication identifier of the connection.
//   late String? _authcid;

//   /// Authorization identity (username)
//   late String? _authzid;

//   /// [String] type password.
//   String? _password;

//   /// Values can be either [String] or a [Map].
//   late final Map<String, dynamic>? _saslData;

//   /// Holds all available mechanisms that are supported by the server.
//   // Map<String, SASL>? _mechanisms;

//   late bool _doAuthentication;
//   late bool _authenticated;
//   late bool _connected;
//   late bool _disconnecting;
//   late bool _paused;
//   late bool _doBind;
//   late bool _doSession;

//   /// Data holder for sending later on. The data it can hold is can be [String]
//   /// or [xml.XmlElement].
//   late final List _data = <dynamic>[];

//   /// The SASL SCRAM client and server keys. This variable will be populated
//   /// with a non-null object of the above described form after a successful
//   /// SCRAM connection.
//   // late List<String> _scramKeys = [];

//   /// This variable appears to be a list used to store instances of the
//   /// [Handler] class, representing XMPP stanza handlers.
//   late final List<Handler> _addHandlers = [];

//   /// This variable appears to be alist used to store instance of the
//   /// [Handler] class which is meant to be removed.
//   late final List<Handler> _removeHandlers = [];

//   /// List of [_TimedHandler]s.This list stores timed handlers. It is declared
//   /// using the `late` keyword, which means it is initialized lazily and can
//   /// be assigned a value later in the code. It is not declared as `final` due
//   /// it can be reassigned in the code later.
//   late List<_TimedHandler> _timedHandlers = [];

//   /// This variable is a list that stores instances of [_Handler] class. It is
//   /// declared using `late`, which means it is initialized lazily and can be
//   /// assigned a value later in code.
//   late List<Handler> _handlers = [];

//   /// This variable appears to be a list used to store references to timed
//   /// handlers that should be removed.
//   late final List<_TimedHandler> _removeTimeds = [];

//   /// The addTimeds variable appears to be a list that holds instances of
//   /// [_TimedHandler] objects. It is used to store and manage timed handlers
//   /// that have been added using the `addTimedHandler` method
//   late final List<_TimedHandler> _addTimeds = [];

//   /// The _idleTimeout variable is a Timer object that handles the idle timeout
//   /// functionality. The purpose of this timer is to invoke the `_onIdle`
//   /// method after a specific duration of idle time. Idle time refers to the
//   /// period during which no activity or interaction occurs.
//   late Timer _idleTimeout;

//   /// Initialize an empty list of [Extension]s.
//   final _extensions = <Extension>[];

//   /// The selected mechanism to provide authentication.
//   // late SASL? _mechanism;

//   /// This variable holds an instance of the [Handler] class that serves as a
//   /// fallback handler for IQ (Info/Query) stanzas.
//   ///
//   /// IQ stanzas are used for exchanging structured data between XMPP entities.
//   /// When an incoming IQ stanza is received and no other specific handler is
//   /// registered to handle it, the fallback handler is triggered.
//   ///
//   /// The purpose of the `_iqFallbackHandler` is to handle IQ stanzas that
//   /// don't have a dedicated handler assigned to them. It ensures that there is
//   /// always a response to incoming IQ stanzas, even if the specific handling
//   /// logic is not defined.
//   late final Handler _iqFallbackHandler;

//   /// This variable holds an instance of the [Handler] class that is responsible
//   /// for handling successful SASL (Simple Authentication and Security Layer)
//   /// authentication. It is initially set to `null`.
//   ///
//   /// SASL authentication is a mechanism used to securely authenticate clients
//   /// and servers in XMPP communication. When the SASL authentication process
//   /// succeeds, the `_saslSuccessHandler` is triggered.
//   ///
//   /// The purpose of the `_saslSuccessHandler` is to handle the successful
//   /// authentication event and perform any necessary actions or logic associated
//   /// with it, such as establishing a session or initializing further
//   /// communication.
//   late Handler? _saslSuccessHandler;

//   /// This variable holds an instance of the Handler class that is responsible
//   /// for handling failed SASL (Simple Authentication and Security Layer)
//   /// authentication. It is initially set to `null`.
//   ///
//   /// If the SASL authentication process fails, the `_saslFailureHandler` is
//   /// triggered. This handler allows for handling and reacting to authentication
//   /// failures, such as incorrect credentials or unsupported authentication
//   /// methods.
//   ///
//   /// The purpose of the `_saslFailureHandler` is to handle the failed
//   /// authentication event and perform any necessary actions or logic associated
//   /// with it, such as displaying an error message or taking corrective
//   /// measures.
//   late Handler? _saslFailureHandler;

//   /// This variable holds an instance of the Handler class that is responsible
//   /// for handling SASL (Simple Authentication and Security Layer)
//   /// authentication challenges. Defaults to `null`.
//   ///
//   /// During the SASL authentication process, challenges may be sent from the
//   /// server to the client, requiring additional information or responses. The
//   /// `_saslChallengeHandler` is triggered when such challenges are received.
//   late Handler? _saslChallengeHandler;

//   /// Attaches an extension to the current connection.
//   ///
//   /// The extension is added to the list of attached extensions for this
//   /// connection.
//   ///
//   /// * @param extension The extension to attach to the connection.
//   void attachExtension<T>(Extension extension) {
//     /// Initialize for the first time.
//     extension.initialize(this);

//     /// Add to the list of extensions.
//     _extensions.add(extension);
//   }

//   /// Sets protocol based to [WebSocketProtocol].
//   void _setProtocol() {
//     /// Check if the service is not empty.
//     if (_service.isEmpty) {
//       // throw TransportException.emptyService();
//     }

//     _transport = WebSocketProtocol(this);
//   }

//   /// Resets the client to its initial state.
//   ///
//   /// It clears various lists, flags and data related to the client's
//   /// configuration, authentication status, connection status, and other
//   /// internal states.
//   void reset() {
//     /// Call the reset method to reset the underlying protocol implementation
//     /// (represented by _protocol) to its initial state.
//     _transport.reset();

//     _handlers.clear();
//     _addHandlers.clear();
//     _removeHandlers.clear();
//     _timedHandlers.clear();
//     _addTimeds.clear();
//     _removeTimeds.clear();
//     _data.clear();
//     _authenticated = false;
//     _connected = false;
//     _disconnecting = false;
//     _doBind = false;
//     _doSession = false;
//   }

//   /// Pause the request manager.
//   ///
//   /// This will prevent [EchoX] from sending any more requests to the server.
//   /// This is very useful for temporarily pausing BOSH-Connections (in our case,
//   /// we will stop accepting something from WebSockets) while a lot of send()
//   /// calls are happening quickly.
//   ///
//   /// This causes [EchoX] to send the data in a single request, saving many
//   /// request trips.
//   void pause() => _paused = true;

//   /// Resume the request manager.
//   ///
//   /// This resumes after `pause()` has been called.
//   void resume() => _paused = false;

//   /// Generates a unique ID for use in <iq /> stanzas.
//   ///
//   /// All <iq /> stanzas are required to have unique id attributes. This
//   /// function makes creating this ease. Each connection instance has a counter
//   /// which starts from zero, and the value of this counter plus a colon
//   /// followed by the `suffix` becomes the unique id. If no suffix is supplied,
//   /// the counter is used as the unique id.
//   ///
//   /// Returns the generated ID.
//   String getUniqueId(dynamic suffix) {
//     /// It follows the format specified by the UUID version 4 standart.
//     final uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
//         .replaceAllMapped(RegExp('[xy]'), (match) {
//       final r = math.Random.secure().nextInt(16);
//       final v = match.group(0) == 'x' ? r : (r & 0x3 | 0x8);
//       return v.toRadixString(16);
//     });

//     /// Check whether the provided suffix is [String] or [int], so if type is
//     /// one of them, proceed to concatting.
//     if (suffix is String || suffix is num) {
//       return '$uuid:$suffix';
//     } else {
//       return uuid;
//     }
//   }

//   /// The main function of this package.
//   ///
//   /// Establishes a connection to the server.
//   ///
//   /// Initiates the process of establishing a connection to the server using the
//   /// provided parameters. It allows you to specify optional authentication
//   /// identifiers and customize disconnection timeout settings.
//   ///
//   /// - [authcid] Optional alternative authentication identifier (authcid) that
//   ///   can be used for authentication. If not provided, the local part of the
//   ///   JID (username) is used as the authcid.
//   /// - [disconnectionTimeout] The disconnection timeout in milliseconds before
//   ///   terminating the connection. Defaults to 1500 milliseconds.
//   ///
//   /// Example:
//   /// ```dart
//   /// final jid = JabberID('hert@example.com');
//   /// final echox = EchoX(jid);
//   /// echox.connect(authcid: 'lerko_user', disconnectionTimeout: 2000);
//   /// ```
//   ///
//   /// The method performs the following tasks:
//   ///
//   /// 1. Sets the authorization identity (authzid) to the bare JID.
//   /// 2. Sets the authentication identity (authcid) to either the provided value
//   ///    or the local part of the JID (username) if not provided.
//   /// 3. Initializes connection state variables.
//   /// 4. Configures the disconnection timeout.
//   /// 5. Emits a 'status' event with the 'connecting' status.
//   /// 6. Initiates the connection process using the specified transport.
//   ///
//   /// See also:
//   ///
//   /// - [JabberID], the class representing Jabber IDs.
//   /// - [StatusEmitter], the class used for emitting status updates.
//   void connect({
//     /// Optional alternative authentication identifier.
//     String? authcid,

//     /// Disconnection timeout before terminating.
//     int disconnectionTimeout = 1500,
//   }) {
//     /// Authorization identity (username).
//     _authzid = jid.bare.toString();

//     /// Authentication identity (user name).
//     _authcid = authcid ?? jid.local;

//     _disconnecting = false;
//     _authenticated = false;
//     _connected = false;

//     _disconnectionTimeout = disconnectionTimeout;

//     /// Parse `jid` for domain.
//     _domain = jid.domain;

//     emit<StatusEmitter>(
//       'status',
//       const StatusEmitter(EchoStatus.connecting),
//     );

//     _transport.connect(['xmpp']);
//   }

//   /// Immediately send any pending outgoing data.
//   ///
//   /// Normally send() queues outgoing data until the next idle period (100ms),
//   /// which optimizes network use in the common cases when several send()s are
//   /// called in succession. flush() can be used to immediately send all pending
//   /// data.
//   void flush() {
//     _idleTimeout.cancel();

//     /// Cancel pending idle period and run the idle function immediately.
//     _onIdle();
//   }

//   /// Sends a stanza.
//   ///
//   /// This method is called to push data onto the send queue to go out over
//   /// the wire. Whenever a request is send to the BOSH server, all pending data
//   /// is sent and the queue is flushed.
//   void send(
//     dynamic message
//     /** xml.XmlElement, [xml.XmlElement], EchoBuilder **/,
//   ) {
//     if (message == null) return;

//     /// If the message is list, then queue all the elements inside of it.
//     if (message is List<xml.XmlElement>) {
//       for (int i = 0; i < message.length; i++) {
//         _queueData(message[i]);
//       }
//     }

//     /// If the message type is [EchoBuilder] then queue the node tree inside of
//     /// it.
//     else if (message.runtimeType == EchoBuilder) {
//       _queueData((message as EchoBuilder).nodeTree);
//     }

//     /// If the message type is [xml.XmlElement], then queue only this one.
//     else {
//       _queueData(message as xml.XmlElement);
//     }

//     /// Run the protocol send function to flush all the available data.
//     _transport.send();
//   }

//   /// Helper function to send IQ stanzas.
//   ///
//   /// * @param element The stanza to send.
//   /// On timeout, the stanza will be null.
//   /// * @param timeout The time specified in milliseconds for a timeout to
//   /// occur.
//   void sendIQ({
//     required xml.XmlElement element,
//     void Function(xml.XmlElement element)? callback,
//     void Function(xml.XmlElement? element)? onError,
//     int? timeout,
//   }) {
//     _TimedHandler? timeoutHandler;
//     String? id = element.getAttribute('id');
//     if (id == null) {
//       id = getUniqueId('sendIQ');
//       element.setAttribute('id', id);
//     }

//     final handler = addHandler(
//       (stanza) {
//         if (timeoutHandler != null) {
//           deleteTimedHandler(timeoutHandler);
//         }
//         final iqType = stanza.getAttribute('type');
//         if (iqType == 'result') {
//           if (callback != null) {
//             callback.call(stanza);
//           }
//         } else if (iqType == 'error') {
//           if (onError != null) {
//             onError.call(stanza);
//           }
//         } else {
//           throw Exception('Got bad IQ type of $iqType');
//         }
//         return false;
//       },
//       name: 'iq',
//       id: id,
//       type: ['result', 'error'],
//     );

//     /// If timeout specified, set up a timeout handler.
//     if (timeout != null) {
//       timeoutHandler = addTimedHandler(timeout, () {
//         /// Get rid of normal handler.
//         deleteHandler(handler);

//         return false;
//       });
//     }

//     send(element);
//   }

//   /// Queues outgoing data for later sending.
//   void _queueData(xml.XmlElement? element) {
//     /// Check if `xmlns` contains the given xmlns attribute, if yes, then
//     /// queue data without check.
//     if (element != null &&
//         element.getAttribute('xmlns') == Echotils.getNamespace('CLIENT')) {
//       _data.add(element);
//       return;
//     }

//     if (element == null ||
//         element.children.isEmpty ||
//         element.name.local.isEmpty) {
//       throw Exception('Cannot queue empty element');
//     }
//     _data.add(element);
//   }

//   /// Send an xmpp:restart stanza.
//   void _sendRestart() {
//     _data.add('restart');
//     _transport._sendRestart();

//     _idleTimeout = Timer(const Duration(milliseconds: 100), _onIdle);
//   }

//   /// Adds a timed handler to the connection.
//   ///
//   /// This function adds a timed handler. The provided handler will be called
//   /// every period milliseconds until it returns false, the connection is
//   /// terminated, or the handler is removed. Handlers that wish to continue
//   /// being invoked should return true.
//   ///
//   /// Because of method binding it is necessary to save the result of this
//   /// function if yuo wish to remove a handler `deleteTimedHandler()`.
//   ///
//   /// Note that user handlers are not active until authentication is successful.
//   _TimedHandler addTimedHandler(int period, bool Function() handler) {
//     /// Declare new [_TimedHandler] object using passed params.
//     final timed = _TimedHandler(period: period, handler: handler);

//     /// Add created [_TimedHandler] to `addTimeds` list.
//     _addTimeds.add(timed);
//     return timed;
//   }

//   /// Deletes a timed handler for a connection.
//   ///
//   /// This function removes a timed handler from the connection. The `reference`
//   /// paramter is not the function passed to `addTimedHandler()`, but the
//   /// reference returned from `addTimedHandler()` method.
//   void deleteTimedHandler(_TimedHandler reference) {
//     /// This must be done in the Idle loop so that we do not change the handlers
//     /// during iteration.
//     _removeTimeds.add(reference);
//   }

//   /// Adds a stanza handler for the connection.
//   ///
//   /// This function adds a stanza `handler` to the connection. The handler
//   /// callback will be called for any stanza that matches the parameters.
//   ///
//   /// Note that if multiple parameters are supplied, they must all match for the
//   /// handler to be invoked.
//   ///
//   /// The handler will receive the stanza that triggered it as its argument.
//   /// __The handler should return true if it is to be invoked again;returning
//   /// false will remove the handler after it returns.__
//   ///
//   /// As a convenience, the `namespace` parameter applies to the top level
//   /// element and also any of its immediate children. This is primarily to make
//   /// matching iq/query elements ease.
//   ///
//   /// * Options
//   /// <br /> With the argument, you can specify boolean flags that affect how
//   /// matches are being done.
//   ///
//   /// Currently two flags exist:
//   ///
//   /// - matchBareFromJid:
//   ///   <br/ > When set to true, the from `parameter` and the from `attribute`
//   ///   on the stanza will be matches as bare JIDs instead of full JIDs. To use
//   ///   this, pass {'matchBareFromJid': true} as the value of options. The
//   ///   default value for `matchBareFromJid` is `false`.
//   ///
//   /// - ignoreNamespaceFragment:
//   ///   <br /> When set to true, a fragment specified on the stanza's namespace
//   ///   URL will be ignored when it is matched with the one configured for the
//   ///   handler.
//   ///
//   /// The return value will be saved if the user wish to remove the handler with
//   /// `deleteHandler()`.
//   Handler addHandler(
//     bool Function(xml.XmlElement)? handler, {
//     String? namespace,
//     String? name,
//     String? id,
//     String? from,
//     dynamic type /** List of types || String */,
//     Map<String, bool>? options,
//   }) {
//     /// Nullable [Handler] object for creating [Handler] with or without
//     /// `completer` parameter.
//     Handler? hand;

//     hand = Handler(
//       handler,
//       name: name,
//       namespace: namespace,
//       type: type,
//       id: id,
//       from: from,
//       options: options,
//     );

//     _addHandlers.add(hand);
//     return hand;
//   }

//   /// Deletes a stanza handler.
//   ///
//   /// This function removes a stanza handler from the connection. The
//   /// `reference` parameter is not the function passed to `addHandler()`,
//   /// but is the reference returned from `addHandler()`.
//   void deleteHandler(Handler reference) {
//     /// Add [Handler] reference to the list of to be removed handlers.
//     ///
//     /// This must be done in the Idle loop so that we do not change the
//     /// handlers during iteration.
//     _removeHandlers.add(reference);

//     final i = _addHandlers.indexOf(reference);
//     if (i >= 0) {
//       _addHandlers.removeAt(i);
//     }

//     return;
//   }

//   /// Register the SASL `mechanisms` which will be supported by this instance of
//   /// [EchoX] (i.e. which this XMPP client will support).
//   void _registerMechanisms() {
//     // _mechanisms = {};

//     /// The list of all available authentication mechanisms.
//     // late final mechanismList = <SASL>[
//     // SASLAnonymous(),
//     // SASLExternal(),
//     // SASLOAuthBearer(),
//     // SASLXOAuth2(),
//     // SASLPlain(),
//     // SASLSHA1(),
//     // SASLSHA256(),
//     // SASLSHA384(),
//     // SASLSHA512(),
//     // ];
//     // mechanismList.map((mechanism) => _registerSASL(mechanism)).toList();
//   }

//   /// Register a single [SASL] `mechanism`, to be supported by this client.
//   // void _registerSASL(SASL mechanism) =>
//   //     _mechanisms![mechanism.name] = mechanism;

//   /// Start the graceful disconnection process with provided [reason].
//   ///
//   /// This function starts the disconnection process. This process starts by
//   /// sending unavailable presence.
//   ///
//   /// If the user supplied connection callback will be notified of the progress
//   /// as this process happens.
//   void disconnect(String? reason) {
//     emit<StatusEmitter>(
//       'status',
//       StatusEmitter(EchoStatus.disconnecting, reason),
//     );

//     emit<String>(
//       'info',
//       'disconnect was called${reason != null ? ' reason: $reason' : ''}',
//     );

//     if (_connected) {
//       EchoBuilder? presence;

//       _disconnecting = true;

//       if (_authenticated) {
//         presence = EchoBuilder.pres(
//           attributes: {
//             'xmlns': Echotils.getNamespace('CLIENT'),
//             'type': 'unavailable',
//           },
//         );
//       }

//       _disconnectTimeout = _addSystemTimedHandler(
//         _disconnectionTimeout,
//         _onDisconnectTimeout,
//       );
//       _transport.abortAllRequests();
//       if (presence != null) {
//         _transport.disconnect(presence.nodeTree);
//       } else {
//         _transport.disconnect();
//       }
//     } else {
//       emit<String>(
//         'info',
//         'disconnect was called before EchoX connected to the server',
//       );

//       _transport.abortAllRequests();
//       _doDisconnect();
//     }
//   }

//   /// Disconnects the XMPP connection.
//   ///
//   /// This is the last piece of the disconnection logic. This resets the
//   /// connection and alerts the user's connection callback.
//   ///
//   /// It takes an optional [condition] parameter which represents the reason or
//   /// condition for disconnecting.
//   void _doDisconnect([String? condition]) {
//     _idleTimeout.cancel();

//     if (_disconnectTimeout != null) {
//       deleteTimedHandler(_disconnectTimeout!);

//       _disconnectTimeout = null;
//     }

//     emit<String>('info', 'doDisconnect method was called');

//     _transport.doDisconnect();

//     _authenticated = false;
//     _disconnecting = false;

//     _handlers = [];

//     _addHandlers.clear();

//     _removeHandlers.clear();

//     _timedHandlers.clear();

//     _addTimeds.clear();

//     _removeTimeds.clear();

//     emit<StatusEmitter>(
//       'status',
//       StatusEmitter(EchoStatus.disconnected, condition),
//     );

//     _connected = false;
//   }

//   /// Handler to process incoming [response] from the connection.
//   ///
//   /// Except for `connectCallback` handling the initial connection request,
//   /// this function handles the incoming data for all requests. This function
//   /// also fires stanza handlers that match each incoming stanza.
//   void _dataReceived(xml.XmlElement response) {
//     final element = _transport.reqToData(response);
//     if (element == null) return;

//     while (_removeHandlers.isNotEmpty) {
//       final hand = _removeHandlers.removeLast();
//       final i = _handlers.indexOf(hand);
//       if (i >= 0) {
//         _handlers.removeAt(i);
//       }
//     }

//     while (_addHandlers.isNotEmpty) {
//       _handlers.add(_addHandlers.removeLast());
//     }

//     if (_disconnecting) {
//       _doDisconnect();
//       return;
//     }

//     final type = element.getAttribute('type');
//     if (type != null && type == 'terminate') {
//       /// Do not process stanzas that come in after disconnect.
//       if (_disconnecting) {
//         return;
//       }

//       /// An error occured.
//       String? condition = element.getAttribute('condition');
//       final conflict = element.getElement('conflict');
//       if (condition != null) {
//         if (condition == 'remote-stream-error' &&
//             conflict!.childElements.isNotEmpty) {
//           condition = 'conflict';
//         }
//         emit<StatusEmitter>(
//           'status',
//           StatusEmitter(EchoStatus.connectionFailed, condition),
//         );
//       } else {
//         emit<StatusEmitter>(
//           'status',
//           StatusEmitter(
//             EchoStatus.connectionFailed,
//             _errorCondition['UNKNOWN_REASON'],
//           ),
//         );
//       }
//       _doDisconnect(condition);
//       return;
//     }

//     /// Send each incoming stanza through the handler chain.
//     Echotils.forEachChild(element, null, (child) async {
//       final matches = <Handler>[];
//       final handlers = <Handler>[];

//       for (final handler in _handlers) {
//         try {
//           if (handler.isMatch(child) && (_authenticated || !handler.user)) {
//             if (await handler.run(child)) {
//               handlers.add(handler);
//             }
//             // matches.add(handler);
//           } else {
//             handlers.add(handler);
//           }
//         } catch (error) {
//           emit<Mishap>(
//             'error',
//             Mishap(
//               condition: 'Removing EchoX handlers due to uncaught exception',
//               text: error.toString(),
//             ),
//           );
//         }
//       }

//       _handlers = handlers;

//       /// If no handler was fired for an incoming IQ with type='set', then we
//       /// return an IQ error stanza with `service-unavailable`.
//       if (matches.isEmpty && _iqFallbackHandler.isMatch(child)) {
//         _iqFallbackHandler.run(child);
//       }
//     });
//   }

//   /// Private binding method.
//   ///
//   /// Sends an IQ to the XMPP server to bind a JID resource for this session.
//   ///
//   /// https://tools.ietf.org/html/rfc6120#section-7.5
//   ///
//   /// If `explicitResourceBinding` was set to a truthy value in the options
//   /// passed to the [EchoX] consructor, then this function needs to be called
//   /// by the client author.
//   ///
//   /// Otherwise it will be called automatically as soon as the XMPP server
//   /// advertises the 'urn:ietf:params:xml:ns:xmpp-bind' stream feature.
//   void _bind() {
//     if (!_doBind) {
//       emit<String>('info', 'EchoX bind called but "do_bind" is false');
//       return;
//     }
//     _addSystemHandler(
//       (element) => _onResourceBindResultIQ(element),
//       id: '_bind_auth_2',
//     );
//     final resource = jid.resource;

//     if (resource != null) {
//       send(
//         EchoBuilder.iq(
//           attributes: {'type': 'set', 'id': '_bind_auth_2'},
//         )
//             .c('bind', attributes: {'xmlns': Echotils.getNamespace('BIND')})
//             .c('resource')
//             .t(resource)
//             .nodeTree,
//       );
//     } else {
//       send(
//         EchoBuilder.iq(
//           attributes: {'type': 'set', 'id': '_bind_auth_2'},
//         ).c(
//           'bind',
//           attributes: {'xmlns': Echotils.getNamespace('BIND')},
//         ).nodeTree,
//       );
//     }
//   }

//   /// Private handler for binding result and session start.
//   bool _onResourceBindResultIQ(xml.XmlElement element) {
//     if (element.getAttribute('type') == 'error') {
//       emit<Mishap>('error', ResourceBindingMishap());
//       final conflict = element.getElement('conflict');
//       String? condition;
//       if (conflict != null) {
//         condition = _errorCondition['CONFLICT'];
//       }
//       emit<StatusEmitter>(
//         'status',
//         StatusEmitter(EchoStatus.authenticationFailed, condition),
//       );
//       return false;
//     }
//     final bind = element.findAllElements('bind').toList();
//     if (bind.isNotEmpty) {
//       final jidNode = bind[0].findAllElements('jid').toList();
//       if (jidNode.isNotEmpty) {
//         _authenticated = true;
//         jid = JabberID.fromString(Echotils.getText(jidNode[0]));
//         if (_doSession) {
//           _establishSession();
//         } else {
//           emit<StatusEmitter>(
//             'status',
//             const StatusEmitter(EchoStatus.connected),
//           );
//         }
//       }
//     } else {
//       emit<StatusEmitter>(
//         'status',
//         const StatusEmitter(EchoStatus.authenticationFailed),
//       );
//       emit<Mishap>('error', ResourceBindingMishap());
//       return false;
//     }
//     return false;
//   }

//   /// Private `connectCallback` method.
//   ///
//   /// SASL authentication will be attempted if available, otherwise the code
//   /// will fall back to legacy authentication.
//   void _connectCallback(
//     xml.XmlElement request,
//     FutureOr<void> Function(EchoX)? callback,
//   ) {
//     emit<String>('info', 'connectCallback method was called');
//     _connected = true;

//     xml.XmlElement? bodyWrap;

//     try {
//       bodyWrap = _transport.reqToData(request);
//     } catch (error) {
//       emit<StatusEmitter>(
//         'status',
//         StatusEmitter(
//           EchoStatus.connectionFailed,
//           _errorCondition['BAD_FORMAT'],
//         ),
//       );
//       _doDisconnect(_errorCondition['BAD_FORMAT']);
//     }

//     if (bodyWrap == null) return;

//     final connectionCheck = _transport._connectCallback(bodyWrap);
//     if (connectionCheck == _status[EchoStatus.connectionFailed]) {
//       return;
//     }

//     /// Check for the stream:features tag
//     bool hasFeatures;
//     hasFeatures =
//         bodyWrap.findAllElements('stream:features').toList().isNotEmpty ||
//             bodyWrap.findAllElements('features').toList().isNotEmpty;

//     if (!hasFeatures) {
//       _transport.nonAuth(callback);
//       return;
//     }

//     final matched = List.from(bodyWrap.findAllElements('mechanism'))
//         .map(
//           (mechanism) => true,
//         )
//         .where((element) => element != null)
//         .toList();

//     if (matched.isEmpty) {
//       if (bodyWrap.childElements
//           .map((element) => element.getElement('auth'))
//           .toList()
//           .isEmpty) {
//         /// There are no matching SASL mechanisms and also no legacy auth
//         /// available.
//         _transport.nonAuth(callback);
//         return;
//       }
//     }

//     // if (_doAuthentication) _authenticate(matched);
//   }

//   // void _authenticate(List<SASL?> mechanisms) {
//   //   if (!_attemptSASLAuth(mechanisms)) {
//   //     _attemptLegacyAuth();
//   //   }
//   // }

//   /// Sorts a list of objects with prototype SASLMechanism according to their
//   /// properties.
//   // List<SASL?> _sortMechanismsByPriority(List<SASL?> mechanisms) {
//   //   /// Iterate over all the available mechanisms.
//   //   for (int i = 0; i < mechanisms.length - 1; i++) {
//   //     int higher = i;
//   //     for (int j = i + 1; j < mechanisms.length; ++j) {
//   //       if (mechanisms[j]!.priority! > mechanisms[higher]!.priority!) {
//   //         higher = j;
//   //       }
//   //     }
//   //     if (higher != i) {
//   //       final swap = mechanisms[i];
//   //       mechanisms[i] = mechanisms[higher];
//   //       mechanisms[higher] = swap;
//   //     }
//   //   }
//   //   return mechanisms;
//   // }

//   /// Iterate through an array of SASL [mechanisms] and attempt authentication
//   /// with the highest priority (enabled) mechanism.
//   // bool _attemptSASLAuth(List<SASL?> mechanisms) {
//   //   final mechs = _sortMechanismsByPriority(mechanisms);
//   //   bool mechanismFound = false;
//   //   for (int i = 0; i < mechs.length; i++) {
//   //     mechanisms[i]!.connection = this;
//   //     if (!mechs[i]!.test()) {
//   //       continue;
//   //     }
//   //     _saslSuccessHandler = _addSystemHandler(
//   //       (element) => _saslSuccessCallback(element),
//   //       name: 'success',
//   //     );
//   //     _saslFailureHandler = _addSystemHandler(
//   //       (element) => _saslFailureCallback(element),
//   //       name: 'failure',
//   //     );
//   //     _saslChallengeHandler = _addSystemHandler(
//   //       (element) => _saslChallengeCallback(element),
//   //       name: 'challenge',
//   //     );

//   //     _mechanism = mechanisms[i];

//   //     final requestAuthExchange = EchoBuilder('auth', {
//   //       'xmlns': Echotils.getNamespace('SASL'),
//   //       'mechanism': _mechanism!.name,
//   //     });
//   //     if (_mechanism!.isClientFirst!) {
//   //       final response = _mechanism!.clientChallenge();
//   //       requestAuthExchange.t(Echotils.btoa(response));
//   //     }
//   //     send(requestAuthExchange.nodeTree);
//   //     mechanismFound = true;
//   //     break;
//   //   }
//   //   return mechanismFound;
//   // }

//   // bool _saslChallengeCallback(xml.XmlElement element) {
//   //   final challenge = Echotils.atob(Echotils.getText(element));
//   //   final response = _mechanism?.onChallenge(challenge: challenge);
//   //   final stanza =
//   //       EchoBuilder('response', {'xmlns': Echotils.getNamespace('SASL')});
//   //   if (response!.isNotEmpty) {
//   //     stanza.t(Echotils.btoa(response));
//   //   }
//   //   send(stanza.nodeTree);

//   //   return true;
//   // }

//   /// Attempt legacy (i.e. non-SASL) authentication.
//   void _attemptLegacyAuth() {
//     emit<StatusEmitter>(
//       'status',
//       const StatusEmitter(EchoStatus.authenticating),
//     );
//     _addSystemHandler(
//       (element) => _onLegacyAuthIQResult(),
//       id: '_auth_1',
//     );

//     send(
//       EchoBuilder.iq(
//         attributes: {'type': 'get', 'to': _domain ?? '', 'id': '_auth_1'},
//       )
//           .c('query', attributes: {'xmlns': Echotils.getNamespace('AUTH')})
//           .c('username')
//           .t(jid.local)
//           .nodeTree,
//     );
//   }

//   /// This handler is called in response to the initial <iq type='get'/> for
//   /// legacy authentication. It builds an authentication <iq/> and sends it,
//   /// creating a handler to handle the result.
//   bool _onLegacyAuthIQResult() {
//     final iq = EchoBuilder.iq(
//       attributes: {'type': 'set', 'id': '_auth_2'},
//     )
//         .c('query', attributes: {'xmlns': Echotils.getNamespace('AUTH')})
//         .c('username')
//         .t(jid.local)
//         .up()
//         .c('password')
//         .t(_password!);

//     String resource = '';

//     if (jid.resource == null) {
//       /// Since the user has not supplied a resource, we pick a default one
//       /// here. Unlike other auth methods, the server cannot do this for us.
//       resource = '${jid.bare}/echox';
//     }
//     iq.up().c('resource', attributes: {}).t(resource);
//     _addSystemHandler(
//       (element) => _auth2Callback(element),
//       id: '_auth_2',
//     );
//     send(iq.nodeTree);
//     return false;
//   }

//   /// Private handler for successful SASL authentication.
//   ///
//   /// This function is invoked when the SASL authentication process succeeds.
//   /// It performs additional checks on the server signature (if available) and
//   /// handles the necessary cleanup and further steps after successful
//   /// authentication.
//   bool _saslSuccessCallback(xml.XmlElement? element) {
//     /// Check server signature (if available). By decoding the success message
//     /// and extracting the server signature attribute. If the server signature
//     /// is invalid, it invokes the SASL failure callback, cleans up the relevant
//     /// handlers, and returns false.
//     if (_saslData!['server-signature'] != null) {
//       String? serverSignature;
//       final success = Echotils.btoa(Echotils.getText(element!));
//       final attribute = RegExp(r'([a-z]+)=([^,]+)(,|$)');
//       final matches = attribute.allMatches(success);
//       for (final match in matches) {
//         if (match.group(1) == 'v') {
//           serverSignature = match.group(2);
//         }
//       }

//       /// Check if server signature is valid.
//       if (serverSignature != null &&
//           serverSignature != _saslData['server-signature']) {
//         /// Remove old handlers
//         deleteHandler(_saslFailureHandler!);

//         /// Make failure handler null.
//         _saslFailureHandler = null;

//         /// Cleanup challenge handler.
//         if (_saslChallengeHandler != null) {
//           deleteHandler(_saslChallengeHandler!);
//           _saslChallengeHandler = null;
//         }

//         /// Clear sasl data.
//         _saslData.clear();
//         return _saslFailureCallback();
//       }
//     }

//     emit<String>('info', 'SASL authentication succeeded');

//     /// Invoke onSuccess callback for the specific mechanism.
//     // if (_mechanism != null) {
//     // _mechanism?.onSuccess();
//     // }

//     /// Remove old handlers
//     deleteHandler(_saslFailureHandler!);
//     _saslFailureHandler = null;
//     if (_saslChallengeHandler != null) {
//       deleteHandler(_saslChallengeHandler!);
//       _saslChallengeHandler = null;
//     }

//     /// Decleration for handling features that constantly streaming while
//     /// connection in the namespace of "stream:features".
//     final streamFeatureHandlers = <Handler>[];

//     /// Wrapper function to handle stream features after SASL authentication.
//     bool wrapper(List<Handler> handlers, xml.XmlElement element) {
//       while (handlers.isNotEmpty) {
//         deleteHandler(handlers.removeLast());
//       }
//       _onStreamFeaturesAfterSASL(element);
//       return false;
//     }

//     /// Add system handlers for stream:features.
//     streamFeatureHandlers.add(
//       _addSystemHandler(
//         (element) => wrapper(streamFeatureHandlers, element),
//         name: 'stream:features',
//       ),
//     );

//     /// Add system handlers for features.
//     streamFeatureHandlers.add(
//       _addSystemHandler(
//         (element) => wrapper(streamFeatureHandlers, element),
//         namespace: Echotils.getNamespace('STREAM'),
//         name: 'features',
//       ),
//     );

//     _sendRestart();
//     return false;
//   }

//   bool _onStreamFeaturesAfterSASL(xml.XmlElement element) {
//     features = element;
//     for (int i = 0; i < element.descendantElements.length; i++) {
//       final child = element.descendantElements.toList()[i];
//       if (child.name.local == 'bind') {
//         _doBind = true;
//       }
//       if (child.name.local == 'session') {
//         _doSession = true;
//       }
//     }
//     if (!_doBind) {
//       emit<StatusEmitter>(
//         'status',
//         const StatusEmitter(EchoStatus.authenticationFailed),
//       );
//       return false;
//     } else if (_options['explicitResourceBinding'] == null ||
//         !(_options['explicitResourceBinding']! as bool)) {
//       _bind();
//     } else {
//       emit<StatusEmitter>(
//         'status',
//         const StatusEmitter(EchoStatus.bindingRequired),
//       );
//     }
//     return false;
//   }

//   /// Send IQ request to establish a session with the XMPP server.
//   ///
//   /// Note: The protocol for session establishment has been determined as
//   /// unnecessary and removed in `RFC-6121`.
//   void _establishSession() {
//     if (!_doSession) {
//       emit<Mishap>('error', EstablishSessionMishap());
//       return;
//     }

//     /// Adds a system handler using the `_addSystemHandler` method. The handler
//     /// is a function that will be called when the session result is received.
//     ///
//     /// The function passed to the handler is `_onSessionResultIQ`, which is
//     /// responsible for handling the session result.
//     _addSystemHandler(
//       (element) => _onSessionResultIQ(element),
//       id: '_session_auth_2',
//     );

//     /// Sends an IQ request to the server using the `send` method.
//     ///
//     /// The IQ request is created using `EchoBuilder.iq` and includes
//     /// attributes such as 'type' (set) and 'id' ('_session_auth_2').
//     /// The IQ request also includes a 'session' element with the 'xmlns'
//     /// attribute set to the value of `urn:ietf:params:xml:ns:xmpp-session`.
//     send(
//       EchoBuilder.iq(
//         attributes: {
//           'type': 'set',
//           'id': '_session_auth_2',
//         },
//       ).c(
//         'session',
//         attributes: {'xmlns': Echotils.getNamespace('SESSION')},
//       ).nodeTree,
//     );
//   }

//   /// Private handler for the server's IQ response to a client's session
//   /// request.
//   ///
//   /// This sets `_authenticated` to true on success, which starts the
//   /// processing of user handlers.
//   ///
//   /// Note: The protocol for sessoin establishment has been determined as
//   /// unnecessary and removed in `RFC-6121`.
//   bool _onSessionResultIQ(xml.XmlElement element) {
//     /// If the 'type' attribute is 'result', it means the session was created
//     /// successfully.
//     if (element.getAttribute('type') == 'result') {
//       /// In this case, the method sets the `_authenticated` variable to `true`.
//       _authenticated = true;

//       emit<StatusEmitter>('status', const StatusEmitter(EchoStatus.connected));
//     }

//     /// If the 'type' attribute is 'error', it means the session creation
//     /// failed.
//     else if (element.getAttribute('type') == 'error') {
//       _authenticated = false;

//       emit<StatusEmitter>(
//         'status',
//         const StatusEmitter(EchoStatus.authenticationFailed),
//       );
//       emit<Mishap>('error', SessionResultMishap());
//       _doDisconnect();

//       return false;
//     }
//     return false;
//   }

//   /// Private handler for SASL authentication failure.
//   bool _saslFailureCallback([xml.XmlElement? element]) {
//     if (_saslChallengeHandler != null) {
//       deleteHandler(_saslChallengeHandler!);
//       _saslChallengeHandler = null;
//     }
//     if (_saslSuccessHandler != null) {
//       deleteHandler(_saslSuccessHandler!);
//       _saslSuccessHandler = null;
//     }
//     // if (_mechanism != null) {
//     // _mechanism?.onFailure();
//     // }

//     emit<StatusEmitter>(
//       'status',
//       const StatusEmitter(EchoStatus.authenticationFailed),
//     );
//     _doDisconnect();
//     return false;
//   }

//   /// Private handler to finish legacy authentication.
//   ///
//   /// This handler is called when the result from the `jabber:iq:auth` <iq/>
//   /// stanza is returned.
//   bool _auth2Callback(xml.XmlElement element) {
//     if (element.getAttribute('type') == 'result') {
//       _authenticated = true;
//       emit<StatusEmitter>('status', const StatusEmitter(EchoStatus.connected));
//     } else if (element.getAttribute('type') == 'error') {
//       emit<StatusEmitter>(
//         'status',
//         const StatusEmitter(EchoStatus.authenticationFailed),
//       );

//       disconnect('Authenticated failed');
//     }
//     return false;
//   }

//   bool _onDisconnectTimeout() {
//     emit<String>('info', 'onDisconnectTimeout method was called');
//     emit<StatusEmitter>(
//       'status',
//       const StatusEmitter(EchoStatus.connectionFailed),
//     );
//     _doDisconnect();
//     return false;
//   }

//   /// Private handler to process events during idle cycle.
//   ///
//   /// This handler is called in every 100ms to fire timed handlers that are
//   /// ready and keep poll request going.
//   void _onIdle() {
//     /// Add timed handlers scheduled for addition
//     while (_addTimeds.isNotEmpty) {
//       _timedHandlers.add(_addTimeds.removeLast());
//     }

//     /// Remove timed handlers that have been scheduled for removal.
//     while (_removeTimeds.isNotEmpty) {
//       final handler = _removeTimeds.removeLast();
//       final i = _timedHandlers.indexOf(handler);
//       if (i >= 0) {
//         _timedHandlers.removeAt(i);
//       }
//     }

//     /// Call ready timed handlers
//     final now = DateTime.now();
//     final newbie = <_TimedHandler>[];
//     for (int i = 0; i < _timedHandlers.length; i++) {
//       final timed = _timedHandlers[i];
//       if (_authenticated || !timed.user) {
//         final since = timed.lastCalled!.millisecondsSinceEpoch + timed.period;
//         if (since - now.millisecondsSinceEpoch <= 0) {
//           if (timed.run()) {
//             newbie.add(timed);
//           }
//         } else {
//           newbie.add(timed);
//         }
//       }
//     }
//     _timedHandlers = newbie;
//     _idleTimeout.cancel();
//     _transport.onIdle();

//     /// Reactivate the timer only if connected
//     if (_connected) {
//       _idleTimeout = Timer(const Duration(milliseconds: 100), () => _onIdle());
//     }
//   }

//   /// Private function to add a system level timed handler.
//   ///
//   /// This function is used to add [_TimedHandler] for the library code. System
//   /// timed handlers are allowed to run before authentication is complete.
//   _TimedHandler _addSystemTimedHandler(int period, bool Function() handler) {
//     /// Create [_TimedHandler] first, for adding to the created handler list.
//     final timed = _TimedHandler(period: period, handler: handler);

//     timed.user = false;

//     _addTimeds.add(timed);
//     return timed;
//   }

//   /// Private method to add a system level stanza handler.
//   ///
//   /// This function is used to add [Handler] for the library code. System
//   /// stanza handlers are allowed to run before authentication is complete.
//   ///
//   /// - [handler] The callback function.
//   /// - [namespace] The namespace match.
//   /// - [name] The stanza name to match.
//   /// - [id] The stanza id attribute to match.
//   /// - [type] The stanza type attribute to match.
//   Handler _addSystemHandler(
//     bool Function(xml.XmlElement) handler, {
//     String? namespace,
//     String? name,
//     String? id,
//     dynamic type /** List of types || String */,
//   }) {
//     /// Create [Handler] for passing to the system handler list.
//     final hand = Handler(
//       handler,
//       namespace: namespace,
//       name: name,
//       type: type,
//       id: id,
//     );

//     /// Equal to false for indicating that this is system handler.
//     hand.user = false;

//     /// Add created [Handler] to the list.
//     _addHandlers.add(hand);

//     return hand;
//   }
// }
