// part of 'echox.dart';

// /// WebSocket connection handler class.
// ///
// /// This class is used internally by [EchoX] to encapsulate WebSocket sessions.
// /// It is not meant to be used from user's code.
// ///
// /// A library to enable XMPP over WebSocket in [EchoX].
// ///
// /// This file implements XMPP over WebSockets for [EchoX], If a connection is
// /// established with a websocket url (ws://...) [EchoX] will use WebSockets.
// class WebSocketProtocol {
//   /// Factory method which returns private instance of this class.
//   factory WebSocketProtocol(EchoX connection) =>
//       WebSocketProtocol._instance(connection);

//   /// Constant instance of private constructor.
//   factory WebSocketProtocol._instance(EchoX connection) =>
//       WebSocketProtocol._(connection);

//   /// [EchoX] representation of `connection` variable. This is used to run
//   /// several methods which is declared inside of this class.
//   late final EchoX _connection;

//   /// Current reconnection attempt count.
//   ///
//   /// The [_currentAttempt] variable holds an integer value that represents the
//   /// current attempt count for reconnection in a WebSocket connection.
//   late int _currentAttempt = 0;

//   /// Backoff strategy for WebSocket reconnection.
//   ///
//   /// Holds an instance of a backoff strategy that determines the timing of
//   /// reconnection attempts in a WebSocket connection.
//   late ws.Backoff backoff = ws.LinearBackoff(
//     initial: const Duration(milliseconds: 1500),
//     increment: const Duration(milliseconds: 3200),
//     maximum: const Duration(milliseconds: 11200),
//   );

//   /// WebSocket initialization. This variable initializes [ws.WebSocket]
//   /// object.
//   ws.WebSocket? _socket;

//   /// Variable for handling listener's onData callback outside of the scope.
//   void Function(String message)? _onMessageCallback;

//   /// Private constructor of the class.
//   WebSocketProtocol._(this._connection);

//   /// Builds a stream using the [EchoBuilder] class.
//   ///
//   /// This method creates an instance of the [EchoBuilder] class with the
//   /// provided parameters and returns it. The `buildStream` method is typically
//   /// used to construct a stream for the XMPP connection.
//   ///  Returns:
//   ///   - An instance of the [EchoBuilder] class representing the built stream.
//   ///
//   /// ### Example:
//   /// ```dart
//   /// final stream = _buildStream();
//   /// // Use the constructed stream for Openfire XMPP connection.
//   /// ```
//   /// Throws:
//   ///   - An exception if the necessary parameters, such as `xmlns`, `to`, or
//   /// `version`, are missing or invalid.
//   xml.XmlElement _buildStream() {
//     final domain = _connection._options['domain'];
//     final lang = _connection._options['lang'];

//     final header = headerElement;
//     header.attributes.addAll([
//       xml.XmlAttribute(xml.XmlName('to'), domain ?? _connection._domain!),
//       xml.XmlAttribute(xml.XmlName('xml:lang'), lang ?? 'en'),
//     ]);

//     return header;
//   }

//   /// Checks for stream errors in the XML element received during the
//   /// connection.
//   ///
//   /// This method searches for stream error elements within the XML element,
//   /// `bodyWrap`, and performs necessary error handling if any errors are found.
//   bool _checkStreamError(
//     xml.XmlElement bodyWrap,
//     EchoStatus status,
//   ) {
//     /// Try to extract error from the provided element if there is a one.
//     final mishap = Mishap.fromElement(bodyWrap);

//     /// If the mishap is null, then exit from the function with false.
//     if (mishap == null) {
//       return false;
//     }

//     /// The method constructs an error string in the format
//     /// "WebSocket stream error: <condition> - <text>" based on the values of
//     /// `condition` and `text`.
//     String errorString = 'WebSocket stream error: ';
//     if (mishap.condition.isNotEmpty) {
//       errorString += mishap.condition;
//     } else {
//       errorString += 'unknown';
//     }
//     if (mishap.text != null) {
//       errorString += ' - ${mishap.text}';
//     }

//     _connection
//       ..emit<Mishap>('error', WebSocketMishap.streamError(errorString))
//       ..emit<StatusEmitter>(
//         'status',
//         StatusEmitter(status, mishap.condition),
//       );

//     _connection.send(Echotils.xmlElement('stream:error', text: 'bad-format'));
//     _connection._doDisconnect();

//     /// The method returns true, indicating that stream errors were encountered
//     /// and handled.
//     return true;
//   }

//   /// Reset the connection.
//   ///
//   /// It is not needed by `WebSockets`.
//   void reset() {
//     return;
//   }

//   /// Establishes a WebSocket connection.
//   void connect([
//     List<String>? protocols /** must be provided for XMPP */,
//   ]) {
//     /// If there is an open connection currently, close it.
//     _closeSocket();

//     final connectionService = _connection._service;
//     final service = socketParameters(connectionService);

//     if (service is String) {
//       /// Establish a WebSocket connection using the connection's service URL
//       /// and 'xmpp' protocol.
//       _socket = ws.WebSocket(
//         Uri.parse(service),
//         protocols: protocols,
//       );
//     } else if (service is Mishap) {
//       _connection.emit<Mishap>('error', service);
//     }

//     void onConnected() {
//       _onOpen.call();

//       _socket!.messages
//         ..listen(
//           (message /** String || List<int> */) {
//             Uint8List data;
//             if (message is String) {
//               data = Echotils.stringToArrayBuffer(message);
//             } else if (message is List<int>) {
//               data = Uint8List.fromList(message);
//             } else {
//               _connection.emit<Mishap>(
//                 'error',
//                 ArgumentMishap(
//                   condition:
//                       'Error occured due the message is coming in the ${message.runtimeType} type',
//                 ),
//               );
//               return;
//             }
//             final utf8Data = utf8.decode(data);
//             _connection.emit('input', utf8Data);

//             if (_onMessageCallback == null) {
//               /// Call the `onInitialMessage` callback if `onMessageCallback`
//               /// is not set.
//               _onInitialMessage(utf8Data);
//             } else {
//               _onMessageCallback!.call(utf8Data);
//             }
//           },
//           onDone: _onClose,
//           onError: _onError,

//           /// Cancel the subscription if an error occurs.
//           cancelOnError: true,
//         )
//         ..handleError((error, trace) {
//           _connection.emit<Mishap>(
//             'error',
//             WebSocketMishap.unknown(error: error, trace: trace),
//           );
//         });
//     }

//     _socket!.connection.listen((state) {
//       if (state is ws.Connected) {
//         onConnected();
//       } else if (state is ws.Reconnecting) {
//         _connection.emit<StatusEmitter>(
//           'status',
//           const StatusEmitter(EchoStatus.reconnecting),
//         );
//         if (_connection._maxReconnectionAttempts != _currentAttempt) {
//           Timer(backoff.next(), () {
//             connect(['xmpp']);
//             _currentAttempt++;
//           });
//         } else {
//           _onClose(1006);
//           disconnect();
//         }
//       } else if (state is ws.Reconnected) {
//         _connection.emit<StatusEmitter>(
//           'status',
//           const StatusEmitter(EchoStatus.reconnected),
//         );
//         onConnected();
//       }
//     });
//   }

//   /// Handles the stream start node of an XML message that is received during
//   /// the XMPP connection.
//   ///
//   /// Performs error checking on the `<open />` tag within the XML message.
//   ///
//   /// Retrieves the value of the "xmlns" attribute and the "version" attribute
//   /// from the `<open />` tag using the `getAttribute` method of the `message`
//   /// object.
//   ///
//   /// The method then performs the following error checks:
//   ///
//   /// * If the "xmlns" attribute is missing or not a string, an error message
//   /// is set indicating that the "xmlns" attribute is missing in the <open />
//   /// tag.
//   /// * If the "xmlns" attribute is present but has a value different from the
//   /// expected XML namespace.
//   bool _handleStreamStart(xml.XmlNode message) {
//     String? error;

//     final namespace = message.getAttribute('xmlns');

//     /// If the "xmlns" attribute is missing, an error message is set indicating
//     /// that the "xmlns" attribute is missing in the `<open />` tag.
//     if (namespace == null) {
//       error = 'Missing xmlns in <open />';
//     }

//     /// If the "xmlns" attribute is present but has a value different from the
//     /// expected XML namespace defined by `ns['FRAMING']`, an error message is
//     /// set indicating that the "xmlns" attribute has the wrong value in the
//     /// `<open />` tag.
//     else if (namespace != Echotils.getNamespace('FRAMING')) {
//       error = 'Wrong xmlns in <open />: $namespace';
//     }

//     /// Checks for errors in the `<version />` tag.
//     final version = message.getAttribute('version');

//     /// If the "version" attribute is missing or not a string, an error message
//     /// is set indicating that the "version" attribute is missing in the
//     /// `<open />` tag.
//     if (version is! String) {
//       error = 'Missing xmlns in <open />';
//     }

//     /// If the "version" attribute is present but has a value different
//     /// from "$VERSION_INDICATOR", an error message is set indicating that
//     /// the "version" attribute has the wrong value in the `<open />` tag.
//     else if (version != '1.0') {
//       error = 'Wrong version in <open />: $version';
//     }

//     if (error != null) {
//       /// If any error is detected, the connection status is changed to a
//       /// connection failure status `EchoStatus.connectionFailed` with the
//       /// corresponding error message.
//       _connection
//         ..emit<StatusEmitter>(
//           'status',
//           const StatusEmitter(EchoStatus.connectionFailed),
//         )
//         ..emit<Mishap>('error', Mishap(condition: error));
//       _connection._doDisconnect();

//       return false;
//     }

//     return true;
//   }

//   /// Connects to the callback based on the XML element received during the
//   /// XMPP connection.
//   ///
//   /// This method checks for stream errors in the XML element using the
//   /// `_checkStreamError` method, which performs error handling if any errors
//   /// are found.
//   ///
//   /// The method receives an `xml.XmlElement` object, [bodyWrap],
//   /// representing the XML element received during the XMPP connection.
//   ///
//   /// Returns the connection status code as an integer.
//   int _connectCallback(xml.XmlElement bodyWrap) {
//     /// Calls `_checkStreamError` method inside, passes `bodyWrap` and the
//     /// [EchoStatus] of connection failed as parameters. If any stream errors
//     /// are detected, then the method returns corresponding failure status
//     /// code.
//     final error = _checkStreamError(bodyWrap, EchoStatus.connectionFailed);
//     if (error) return _status[EchoStatus.connectionFailed]!;

//     /// If no stream errors are found, indicating a successful connection, the
//     /// method returns connection status code.
//     return _status[EchoStatus.connected]!;
//   }

//   /// Handles the initial message received during the XMPP connection.
//   ///
//   /// This method is responsible for processing the initial message received
//   /// from the server during the connection and taking appropriate actions
//   /// based on the content of the message.
//   ///
//   /// Receives a [message], which represents the initial message received from
//   /// the server.
//   void _onInitialMessage(String message) {
//     /// If the message starts with '<open ' or '<?xml', indicating the start
//     /// of the XMPP stream, the method performs the following actions.
//     if (message.startsWith('<open ') || message.startsWith('<?xml')) {
//       /// Removes any leading XML declaration (if present) from the message
//       /// using a regular expression.
//       final data = message.replaceAll(RegExp(r'^(<\?.*?\?>\s*)*'), '');

//       /// Due replaced data can be empty, ensures this check.
//       if (data.isEmpty) return;

//       /// Parses the remaining data as an XML element.
//       final streamStart = xml.XmlDocument.parse(data).rootElement;

//       /// Calls the `_handleStreamStart` method, passing the parsed XML element,
//       /// to check for errors in the <open /> tag and handle the stream start.
//       if (_handleStreamStart(streamStart)) {
//         /// If the stream start handling is successful, calls this method,
//         /// passes the parsed XML element to connect to the callback based on
//         /// the received data.
//         _connectCallback(streamStart);
//       }
//     }

//     /// If the message starts with '<close', indicating the closing of the XMPP
//     /// stream, the method performs the following actions:
//     else if (message.startsWith('<close')) {
//       /// Parses the message as an XML document.
//       final parsed = xml.XmlDocument.parse(message);

//       /// Retrieves the value of the 'see-other-uri' attribute from the parsed
//       /// XML document.
//       final see = parsed.getAttribute('see-other-uri');

//       /// If the 'see-other-uri' attribute is present, checks if the redirect
//       /// is secure by comparing the current service and the 'see-other-uri'
//       /// value.
//       if (see != null) {
//         final service = _connection._service;
//         final isSecureRedirect =
//             (service.contains('wss:') && see.contains('wss:')) ||
//                 service.contains('ws:');

//         /// If the redirect is secure, changes the connection status to
//         /// `EchoStatus.redirect`, resets the connection, updates the connection
//         /// with the 'see-other-uri' value, and initiates a new connection.
//         if (isSecureRedirect) {
//           _connection.emit<StatusEmitter>(
//             'status',
//             const StatusEmitter(
//               EchoStatus.redirect,
//               'Received see-other-uri, resetting connection',
//             ),
//           );
//           _connection.reset();
//           _connection._service = see;
//           connect();
//         }
//       }

//       /// If the 'see-other-uri' attribute is not present, changes the
//       /// connection status to `Status.connfail` with the message
//       /// 'Received closing stream' and performs a disconnection.
//       else {
//         _connection.emit<StatusEmitter>(
//           'status',
//           const StatusEmitter(
//             EchoStatus.connectionFailed,
//             'Received closing stream',
//           ),
//         );

//         _connection._doDisconnect();
//       }
//     } else {
//       /// Replaces the current message handler callback with the default
//       /// message handling method using the `_replaceMessageHandler` method.
//       _replaceMessageHandler();

//       /// Wraps the message in an XML stream using the `_streamWrap` method.
//       final string = _streamWrap(message);

//       /// Parses the wrapped message as an XML document.
//       final element = xml.XmlDocument.parse(string);
//       _connection._connectCallback(element.rootElement, null);
//     }
//   }

//   /// Handles incoming XMPP messages received over the WebSocket connection.
//   ///
//   /// Accepts [String] type [message] variable, that indicates the message
//   /// received over the socket.
//   ///
//   /// Since all XMPP traffic starts with
//   /// ```xml
//   ///  <stream:stream version='1.0'
//   ///                 xml:lang='en'
//   ///                 xmlns='jabber:client'
//   ///                 xmlns:stream='http://etherx.jabber.org/streams'
//   ///                 id='someID'
//   ///                 from='SERVER'>
//   /// ```
//   /// The first stanza will always fail to be parsed.
//   void _onMessage(String message) {
//     xml.XmlElement? element;

//     const close = '<close xmlns="urn:ietf:params:xml:ns:xmpp-framing" />';

//     /// Starts by checking if the message represents a closing stream.
//     ///
//     /// If the message is a closing stream message, it notifies the connection,
//     /// and disconnects if the connection is in the disconnecting state.
//     if (message == close) {
//       if (!_connection._disconnecting) {
//         _connection._doDisconnect();
//       }
//       return;
//     } else if (message.contains('<open ')) {
//       element = xml.XmlDocument.parse(message).rootElement;
//       if (!_handleStreamStart(element)) {
//         return;
//       }
//     }

//     /// If the message doesn't represent a closing stream or a stream start,
//     /// it is wrapped using `_streamWrap` and then parsed into an XML element.
//     else {
//       final data = _streamWrap(message);
//       element = xml.XmlDocument.parse(data).rootElement;
//     }

//     if (_checkStreamError(element, EchoStatus.error)) {
//       return;
//     }

//     _connection._dataReceived(element);
//   }

//   /// Called on stream start/restart when no `stream:features` has been
//   /// received.
//   ///
//   /// When the authentication is not supported, then passed [callback] must be
//   /// called
//   void nonAuth([FutureOr<void> Function(EchoX)? callback]) {
//     _connection
//       ..emit<Mishap>(
//         'error',
//         Mishap(
//           condition:
//               'Server did not offer a supported authentication mechanism',
//         ),
//       )

//       /// Change the status to the not supported authentication mechanism.
//       ..emit<StatusEmitter>(
//         'status',
//         StatusEmitter(
//           EchoStatus.connectionFailed,
//           _errorCondition['NO_AUTH_MECH'],
//         ),
//       );

//     if (callback != null) {
//       callback.call(_connection);
//     }

//     _connection._doDisconnect();
//   }

//   /// Disconnects the socket connection and performs necessary cleanup actions.
//   ///
//   /// Accepts only a parameter representing the presence to be sent before
//   /// disconnecting.
//   ///
//   /// * A `close` XML element is created using [EchoBuilder] with the `xmlns`
//   /// attribute.
//   /// * The XML tree representation of the `close` element is sent using the
//   /// connection's `_xmlOutput()` method.
//   /// * The `close` node tree is serialized to a string using
//   /// `Echotils.serialize()`.
//   void disconnect([xml.XmlElement? presence]) {
//     /// Check if the socket is not null and its state is not equal to 3 (closed).
//     if (_socket != null) {
//       /// If presence is provided, send the presence using the connection.
//       if (presence != null) {
//         _connection.send(presence);
//       }

//       /// Create a 'close' XML element using [EchoBuilder] with 'xlmns'
//       /// attribute.
//       final close =
//           EchoBuilder('close', {'xmlns': Echotils.getNamespace('FRAMING')});

//       /// Serialize the 'close' node tree to a string.
//       final closeString = Echotils.serialize(close.nodeTree);

//       _socket!.send(closeString);
//     }

//     return _connection._doDisconnect();
//   }

//   /// Just closes the Socket.
//   void doDisconnect() {
//     _connection.emit<String>(
//       'info',
//       "WebSocket's doDisconnect method is called",
//     );

//     _closeSocket();
//   }

//   /// Helper function to wrap a stanza in a <stream> tag.
//   ///
//   /// With this method [EchoX] can process stanzas from WebSockets like BOSH.
//   String _streamWrap(String stanza) => '<wrapper>$stanza</wrapper>';

//   /// Replaces the message handler callback with the default message handling
//   /// method.
//   ///
//   /// This method assigns the `_onMessage` method as the new message handler
//   /// method, due this assign process will take place after initial message
//   /// get.
//   ///
//   /// The `_onMessage` method is responsible for handling incoming messages and
//   /// performing any necessary actions or processing.
//   void _replaceMessageHandler() => _onMessageCallback = _onMessage;

//   /// Function to check if the message queue is empty.
//   ///
//   /// Returns `true`, because WebSocket messages are send immediately after
//   /// queueing.
//   bool emptyQueue() => true;

//   /// Timeout handler for handling non-graceful disconnecting.
//   ///
//   /// This does nothing for WebSocket.
//   void onDisconnectTimeout() {}

//   /// Helper function that makes sure all pending requests are aborted.
//   void abortAllRequests() {}

//   /// Handles processing of idle connection state. Sends all queued stanzas.
//   ///
//   /// This method sends any pending data from the connection when the connection
//   /// is idle.
//   void onIdle() {
//     final data = _connection._data;

//     /// Check if there is pending data and the connection is not paused.
//     if (data.isNotEmpty && !_connection._paused) {
//       for (int i = 0; i < data.length; i++) {
//         if (data[i] != null) {
//           xml.XmlElement stanza;

//           /// Check the type of the data element and build the appropriate XML
//           /// stanza
//           if (data[i] == 'restart') {
//             stanza = _buildStream();
//           } else {
//             stanza = data[i] as xml.XmlElement;
//           }

//           /// Serialize the stanza to a raw string.
//           final rawStanza = Echotils.serialize(stanza);

//           _socket!.send(rawStanza);
//         }
//       }

//       /// Clear the connection's data list after sending all the pending data.
//       _connection._data.clear();
//     }
//   }

//   /// Event handler called when the WebSocket connection is successfully opened.
//   ///
//   /// This method logs an informational message indicating that the `WebSocket`
//   /// is open.
//   void _onOpen() {
//     _connection.emit<String>('info', 'WebSocket is open');

//     /// It creates and sends an initial XMPP stream to the server, using the
//     /// `_buildStream` method.
//     final start = _buildStream();

//     /// The node tree serialized using [Echotils]'s serialize method.
//     final startString = Echotils.serialize(start);

//     /// Finally, the stream string is sent over the WebSocket connection by
//     /// adding it to the socket's buffer.
//     _socket!.send(startString);
//   }

//   /// Event handler called when the WebSocket connection is closed.
//   ///
//   /// Checks the state of the connection and performs different actions based on
//   /// the state.
//   Future<void> _onClose([int? code, String? reason]) async {
//     /// If the connection is currently connected and not in the process of
//     /// disconnecting,
//     if (_connection._connected && !_connection._disconnecting) {
//       _connection.emit<WebSocketMishap>(
//         'error',
//         WebSocketMishap.unexpected(code: code, reason: reason),
//       );
//       _connection._doDisconnect();
//     }

//     /// If the connection is not currently connected, an error message is
//     /// logged indicating that the `WebSocket` connection was closed
//     /// unexpectedly.
//     ///
//     /// If closing code is not null and equals to the specific number which
//     /// indicates to `1006` in this case, this means that `websocket` is closed
//     /// unexpectedly.
//     else if (_socket != null &&
//         code != null &&
//         code == 1006 &&
//         !_connection._connected) {
//       _connection.emit<WebSocketMishap>(
//         'error',
//         WebSocketMishap.unexpected(code: code, reason: reason),
//       );

//       /// The connection status is updated to a connection failure status with
//       /// an appropriate error message.
//       _connection.emit<StatusEmitter>(
//         'status',
//         const StatusEmitter(
//           EchoStatus.connectionFailed,
//           'WebSocket connection could not be established or was disconnected',
//         ),
//       );
//     } else {
//       _connection.emit<String>('info', 'WebSocket closed');
//     }
//   }

//   /// Event handler called when an error occurs in the `WebSocket` connection.
//   ///
//   /// This method logs an error message indicating that a `WebSocket` error
//   /// occurred.
//   ///
//   /// It then calls the `connection._changeConnectStatus` method to update the
//   /// connection status with a connection failure status and an appropriate
//   /// error message.
//   void _onError(dynamic error, dynamic trace) {
//     _connection
//       ..emit<Mishap>(
//         'error',
//         WebSocketMishap.unknown(error: error, trace: trace),
//       )
//       ..emit<StatusEmitter>(
//         'status',
//         const StatusEmitter(
//           EchoStatus.connectionFailed,
//           'The websocket connection could not be established or was disconnected',
//         ),
//       );
//   }

//   /// Closes the WebSocket connection.
//   ///
//   /// * If a WebSocket connection is currently open, it is closed gracefully.
//   /// * If an error occurs during the closing process, an info log is generated.
//   /// * After closing the connection, the socket reference is set to null.
//   void _closeSocket([int closeCode = 1000, String? reason]) {
//     if (_socket != null) {
//       /// It performs a graceful closing of the connection by calling the
//       /// `close()` method on the WebSocket object
//       _socket!.close(closeCode, reason);
//     }

//     _socket = null;
//   }

//   /// Sends any pending data from the connection.
//   ///
//   /// Just flushes the messages that are in the queue.
//   void send() => _connection.flush();

//   /// Method to get a stanza out of a request.
//   ///
//   /// WebSockets do not use requests, so the passed argument is just returned.
//   xml.XmlElement? reqToData(xml.XmlElement? stanza) => stanza;

//   /// Check if the URL is valid WebSocket URL, if not then return
//   /// [WebSocketMishap].
//   dynamic socketParameters(String service) {
//     bool isValid = false;

//     if (RegExp(
//       r'^ws(s)?://([a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*(:[0-9]+)?)?(/([a-zA-Z0-9-._~!$&\"()*+,;=:@]+))*$',
//     ).hasMatch(service)) {
//       isValid = true;
//     }
//     return isValid ? service : WebSocketMishap.incorrectURL(service);
//   }

//   /// Send an xmpp:restart stanza.
//   void _sendRestart() {
//     _connection._idleTimeout.cancel();
//     _connection._onIdle();
//   }

//   /// Getter for the XML header element.
//   ///
//   /// The `headerElement` getter returns an [xml.XmlElement] representing the XML
//   /// header typically found at the beginning of an XML document. This header
//   /// includes attributes for specifying the XML version and the XML namespace
//   /// related to framing.
//   ///
//   /// Example:
//   /// ```dart
//   /// final header = headerElement;
//   /// print(header);
//   /// ```
//   ///
//   /// Returns:
//   /// ```xml
//   /// <?xml version="1.0" xmlns="FRAMING"?>
//   /// ```
//   ///
//   /// The getter uses the [Echotils.xmlElement] method to create the XML element
//   /// with the specified tag name ('open') and attributes ('version' and 'xmlns').
//   ///
//   /// See also:
//   ///
//   /// - [Echotils.xmlElement], the method used to create XML elements.
//   /// - [xml.XmlElement], the class representing XML elements in the xml package.
//   ///
//   xml.XmlElement get headerElement => Echotils.xmlElement(
//         'open',
//         attributes: {
//           'version': '1.0',
//           'xmlns': Echotils.getNamespace('FRAMING'),
//         },
//       );
// }

// /// An exception representing a mishap related to function arguments.
// ///
// /// The [ArgumentMishap] class is an extension of the [Mishap] class and is used
// /// to represent exceptions that occur due to issues related to provided service
// /// arguments.
// class ArgumentMishap extends Mishap {
//   ArgumentMishap({required super.condition});
// }

// /// Connection status constants for use by the connection handler callback.
// ///
// /// * _status[ERROR]_ - An error has occurred.
// /// * _status[CONNECTING]_ - The connection is currently being made.
// /// * _status[CONNECTIONFAILED]_ - The connection attempt failed.
// /// * _status[AUTHENTICATING]_ - The connection is authenticating.
// /// * _status[AUTHENTICATIONFAILED]_ - The authentication attempt failed.
// /// * _status[CONNECTED]_ - The connection has succeeded.
// /// * _status[DISCONNECTED]_ - The connection has been terminated.
// /// * _status[DISCONNECTING]_ - The connection is currently being terminated.
// /// * _status[REDIRECT]_ - The connection has been redirected.
// /// * _status[CONNECTIONTIMEOUT]_ - The connection has timed out.
// const _status = <EchoStatus, int>{
//   EchoStatus.error: 0,
//   EchoStatus.connecting: 1,
//   EchoStatus.connectionFailed: 2,
//   EchoStatus.authenticating: 3,
//   EchoStatus.authenticationFailed: 4,
//   EchoStatus.connected: 5,
//   EchoStatus.disconnected: 6,
//   EchoStatus.disconnecting: 7,
//   EchoStatus.redirect: 8,
//   EchoStatus.connectionTimeout: 9,
//   EchoStatus.bindingRequired: 10,
// };

// const _errorCondition = {
//   'BAD_FORMAT': 'bad-format',
//   'CONFLICT': 'conflict',
//   'MISSING_JID_NODE': "x-strophe-bad-non-anon-jid",
//   'NO_AUTH_MECH': "no-auth-mech",
//   'UNKNOWN_REASON': "unknown",
// };
