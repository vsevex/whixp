import 'dart:async';
import 'dart:io' as io;

import 'package:echo/echo.dart';
import 'package:echo/src/constants.dart';
import 'package:echo/src/log.dart';
import 'package:echo/src/protocol.dart';
import 'package:echo/src/utils.dart';

import 'package:xml/xml.dart' as xml;

/// Websocket connection handler class.
///
/// This class is used internally by [Echo] to encapsulate Websocket sessions.
/// It is not meant to be used from user's code.
///
/// A library to enable XMPP over Websocket in [Echo].
///
/// This file implements XMPP over Websockets for [Echo], If a connection is
/// established with a websocket url (ws://...) [Echo] will use Websockets.
class Websocket extends Protocol {
  /// Factory method which returns private instance of this class.
  factory Websocket(Echo connection) => Websocket._instance(connection);

  /// Constant instance of private constructor.
  factory Websocket._instance(Echo connection) => Websocket._(connection);

  /// [Echo] representation of `connection` variable. This is used to run
  /// several methods which is declared inside of this class.
  final Echo connection;

  /// Websocket initialization. This variable assigns pure dart library named
  /// `io`'s websocket object.
  io.WebSocket? socket;

  /// Variable for handling listener's onData callback outside of the scope.
  void Function(String message)? _onMessageCallback;

  /// Private constructor of the class.
  Websocket._(this.connection) {
    /// Retrieve the 'service' property from the connection
    final service = connection.service;

    /// Set the default value for the 'strip' variable
    super.strip = 'wrapper';

    /// Check if the service does not start with 'ws:' or 'wss:'
    if (!service.startsWith('ws:') && !service.startsWith('wss:')) {
      String newService = '';

      /// Determine the protocol based on the 'protocol' option in the
      /// connection's options map.
      if (connection.options['protocol'] == 'ws') {
        newService += 'ws';
      } else {
        newService += 'wss';
      }

      /// Construct the new service URL using the current host
      newService += '://${Uri.base.host}';

      /// Append the base path and service if necessary
      if (newService.indexOf('/') != 0) {
        newService += Uri.base.path + service;
      } else {
        newService += service;
      }

      /// Update the connection's service with the new constructed service URL
      connection.service = newService;
    }
  }

  /// Builds a stream using the [EchoBuilder] class.
  ///
  /// This method creates an instance of the [EchoBuilder] class with the
  /// provided parameters and returns it. The `buildStream` method is typically
  /// used to construct a stream for the XMPP connection.
  ///  Returns:
  ///   - An instance of the [EchoBuilder] class representing the built stream.
  ///
  /// ### Example usage:
  /// ```dart
  /// final stream = _buildStream();
  /// // Use the constructed stream for Openfire XMPP connection.
  /// ```
  /// Throws:
  ///   - An exception if the necessary parameters, such as `xmlns`, `to`, or
  /// `version`, are missing or invalid.
  EchoBuilder _buildStream() => EchoBuilder('open', {
        'xmlns': ns['FRAMING'],
        'to': connection.domain,
        'version': '1.0',
      });

  /// Checks for stream errors in the XML document received during the XMPP
  /// connection.
  ///
  /// This method searches for stream error elements within the XML document,
  /// `bodyWrap`, and performs necessary error handling if any errors are found.
  bool _checkStreamError(xml.XmlElement bodyWrap, Status status) {
    /// The method begins by declaring a `List<xml.XmlElement>` variable named
    /// `errors` to store the stream error elements found in the XML document.
    ///
    List<xml.XmlElement>? errors;

    /// The method searches for stream error elements using the `findElements`
    /// method of the `bodyWrap` XML document. It looks for elements with the
    /// XML namespace specified by `ns['STREAM']` and the namespace "error".
    errors = bodyWrap
        .findElements(
          ns['STREAM']!,
          namespace: 'error',
        )
        .toList();

    /// If no elements are found, it falls back to searching for elements
    /// with the name "error" without a specific namespace.
    if (errors.isEmpty) errors = bodyWrap.findElements('error').toList();

    /// If no stream error elements are found, the method returns `false`,
    /// indicating that no errors were encountered.
    if (errors.isEmpty) return false;

    /// If stream error elements are found, the method retrieves the first error
    /// element.
    final error = errors[0];

    /// Extracts the condition and text values associated with the error.
    String condition = '';
    String text = '';

    /// The method iterates through the child elements of the error element
    /// and checks if their "xmlns" attribute matches the expected namespace
    /// ("urn:ietf:params:xml:ns:xmpp-streams").
    const namespace = "urn:ietf:params:xml:ns:xmpp-streams";
    for (final e in error.children) {
      /// If the attribute does not match, the iteration is stopped.
      if (e.getAttribute('xmlns') != namespace) {
        break;
      }

      /// If an element with the local name "text" is found, its inner text is
      /// assigned to the `text` variable.
      if (e.nodeType == xml.XmlNodeType.ELEMENT &&
          (e as xml.XmlElement).name.local == "text") {
        text = e.innerText;
      } else {
        /// Otherwise, the local name of the first child element is assigned to
        /// the `condition` variable.
        condition = e.firstElementChild!.localName;
      }
    }

    /// The method constructs an error string with the format
    /// "Websocket stream error: <condition> - <text>" based on the values of
    /// `condition` and `text`.
    String errorString = 'Websocket stream error: ';
    if (condition.isNotEmpty) {
      errorString += condition;
    } else {
      errorString += 'unknown';
    }
    if (text.isNotEmpty) {
      errorString += ' - $text';
    }

    /// The error string is logged using the `Log().error` method.
    Log().error(errorString);

    /// The connection status is changed to the specified `status` and the
    /// error condition is passed as the reason using the
    /// `connection.changeConnectStatus` method.
    connection.changeConnectStatus(status, condition);

    /// The connection is then disconnected using the `connection.doDisconnect`
    /// method.
    connection.doDisconnect();

    /// The method returns `true`, indicting that stream errors were encountered
    /// and handled.
    return true;
  }

  /// Reset the connection.
  ///
  /// It is not needed by `WebSockets`.
  @override
  void reset() {
    return;
  }

  /// Establish a Websocket connection.
  ///
  /// After connection assigns Callbacks to it.
  /// Does nothing if there already a Websocket.
  /// * @return A Future that completes when the WebSocket connection is
  /// established.
  @override
  Future<void> connect() async {
    /// If there is an open connection currently, close it.
    _closeSocket();

    try {
      /// Establish a WebSocket connection using the connection's service URL and
      /// 'xmpp' protocol.
      socket =
          await io.WebSocket.connect(connection.service, protocols: ['xmpp']);

      /// Check the connection is in the `open` state.
      if (socket!.readyState == 1) {
        /// Invoke `onOpen` method afterwards.
        _onOpen.call();

        /// Listen for incoming messages on the socket.
        socket!.listen(
          (message) {
            if (_onMessageCallback == null) {
              /// Call the `onInitialMessage` callback if `onMessageCallback` is
              /// not set.
              _onInitialMessage(message as String);
            } else {
              _onMessageCallback!.call(message as String);
            }
          },

          /// Invoke the `_onClose` callback when the socket is closed.
          onDone: _onClose,

          /// Invoke the `_onError` callback if there is an error.
          onError: _onError,

          /// Cancel the subscription if an error occurs.
          cancelOnError: true,
        );
      }

      /// Invoke the _onClose callback with the socket's close code when the
      /// socket is in CLOSING state.
      else if (socket!.readyState == 2) {
        _onClose(code: socket!.closeCode);
      }
    } catch (error) {
      print(error);
    }
  }

  /// Connects to the callback based on the XML element received during the
  /// XMPP connection.
  ///
  /// This method checks for stream errors in the XML element using the
  /// `_checkStreamError` method, which performs error handling if any errors
  /// are found.
  ///
  /// The method receives an `xml.XmlElement` object, `bodyWrap`,
  /// representing the XML element received during the XMPP connection.
  /// Returns the connection status code as an integer:
  /// * - If there are stream errors indicating a failed connection,
  /// returns `status[Status.connfail]`.
  /// * - If there are no stream errors indicating a successful connection,
  /// returns `status[Status.connected]`.
  @override
  int connectCB(xml.XmlElement bodyWrap) {
    /// Calls `_checkStreamError` method inside, passes `bodyWrap` and the
    /// [Status] of connection failed as parameters. If any stream errors
    /// are detected, then the method returns corresponding failure status
    /// code.
    final error = _checkStreamError(bodyWrap, Status.connfail);
    if (error) return status[Status.connfail]!;

    /// If no stream errors are found, indicating a successful connection, the
    /// method returns connection status code.
    return status[Status.connected]!;
  }

  /// Handles the stream start node of an XML message received during the XMPP
  /// connection.
  ///
  /// This method performs error checking on the `<open />` tag within the XML
  /// message.
  ///
  /// It retrieves the value of the "xmlns" attribute and the "version"
  /// attribute from the `<open />` tag using the `getAttribute` method of the
  /// `message` object.
  ///
  /// The method then performs the following error checks:

  /// * If the "xmlns" attribute is missing or not a string, an error message
  /// is set indicating that the "xmlns" attribute is missing in the <open />
  /// tag.
  /// * If the "xmlns" attribute is present but has a value different from the
  /// expected XML namespace.
  bool _handleStreamStart(xml.XmlNode message) {
    /// Nullable `error` variable initialization.
    String? error;

    // Check for errors in the <open /> tag.
    final namespace = message.getAttribute('xmlns');

    /// If the "xmlns" attribute is missing, an error message is set indicating
    /// that the "xmlns" attribute is missing in the `<open />` tag.
    if (namespace == null) {
      error = 'Missing xmlns in <open />';
    }

    /// If the "xmlns" attribute is present but has a value different from the
    /// expected XML namespace defined by `ns['FRAMING']`, an error message is
    /// set indicating that the "xmlns" attribute has the wrong value in the
    /// `<open />` tag.
    else if (namespace != ns['FRAMING']) {
      error = 'Wrong xmlns in <open />: $namespace';
    }

    /// Checks for errors in the <version /> tag.
    final version = message.getAttribute('version');

    /// If the "version" attribute is missing or not a string, an error message
    /// is set indicating that the "version" attribute is missing in the
    /// `<open />` tag.
    if (version is! String) {
      error = 'Missing xmlns in <open />';
    }

    /// If the "version" attribute is present but has a value different
    /// from "$VERSION_INDICATOR", an error message is set indicating that
    /// the "version" attribute has the wrong value in the `<open />` tag.
    else if (version != '1.0') {
      error = 'Wrong version in <open />: $version';
    }

    if (error != null) {
      /// If any error is detected, the connection status is changed to a
      /// connection failure status `Status.connfail` with the corresponding
      /// error message using the `connection.changeConnectStatus` method.
      connection.changeConnectStatus(Status.connfail, error);

      /// The connection is then disconnected by calling the
      /// `connection.doDisconnect` method, and the method returns `false`.
      connection.doDisconnect();

      /// Returns `false` if there is not any error.
      return false;
    }

    /// Returns `true` in the case of error.
    return true;
  }

  /// Handles the initial message received during the XMPP connection.
  ///
  /// This method is responsible for processing the initial message received
  /// from the server during the connection and taking appropriate actions
  /// based on the content of the message.
  ///
  /// The method receives a [String] parameter named `message`, which
  /// represents the initial message received from the server.
  void _onInitialMessage(String message) {
    /// If the message starts with '<open ' or '<?xml', indicating the start
    /// of the XMPP stream, the method performs the following actions:
    if (message.startsWith('<open ') || message.startsWith('<?xml')) {
      /// Removes any leading XML declaration (if present) from the message
      /// using a regular expression.
      final data = message.replaceAll(RegExp(r'^(<\?.*?\?>\s*)*'), '');

      /// Due replaced data can be empty, ensures that this check.
      if (data.isEmpty) return;

      /// Parses the remaining data as an XML element.
      final streamStart = xml.XmlDocument.parse(data).rootElement;

      /// Calls the `connection.xmlInput` method, passing the root element of
      /// the parsed XML element, to handle the XML input.
      connection.xmlInput(streamStart);

      /// Calls the `connection.rawInput` method, passing the original message,
      /// to handle the raw input.
      connection.rawInput(message);

      /// Calls the `_handleStreamStart` method, passing the parsed XML element,
      /// to check for errors in the <open /> tag and handle the stream start.
      if (_handleStreamStart(streamStart)) {
        /// If the stream start handling is successful, calls this method,
        /// passes the parsed XML element to connect to the callback based on
        /// the received data.
        connectCB(streamStart);
      }
    }

    /// If the message starts with '<close', indicating the closing of the XMPP
    /// stream, the method performs the following actions:
    else if (message.startsWith('<close')) {
      /// Parses the message as an XML document.
      final parsed = xml.XmlDocument.parse(message);

      /// Calls the `connection.xmlInput` method, passing the root element of
      /// the parsed XML document, to handle the XML input.
      connection.xmlInput(parsed.rootElement);

      /// Calls the `connection.rawInput` method, passing the original message,
      /// to handle the raw input.
      connection.rawInput(message);

      /// Retrieves the value of the 'see-other-uri' attribute from the parsed
      /// XML document.
      final see = parsed.getAttribute('see-other-uri');

      /// If the 'see-other-uri' attribute is present, checks if the redirect
      /// is secure by comparing the current service and the 'see-other-uri'
      /// value.
      if (see != null) {
        final service = connection.service;
        final isSecureRedirect =
            (service.contains('wss:') && see.contains('wss:')) ||
                service.contains('ws:');

        /// If the redirect is secure, changes the connection status to
        /// Status.redirect`, resets the connection, updates the connection
        /// service with the 'see-other-uri' value, and initiates a new
        /// connection.
        if (isSecureRedirect) {
          connection.changeConnectStatus(
            Status.redirect,
            'Received see-other-uri, resetting connection',
          );
          connection.reset();
          connection.service = see;
          connect();
        }
      }

      ///If the 'see-other-uri' attribute is not present, changes the
      ///connection status to `Status.connfail` with the message
      ///'Received closing stream' and performs a disconnection.
      else {
        connection.changeConnectStatus(
          Status.connfail,
          'Received closing stream',
        );

        /// Disconnects from the connection.
        connection.doDisconnect();
      }
    } else {
      /// Replaces the current message handler callback with the default
      /// message handling method using the `_replaceMessageHandler` method.
      _replaceMessageHandler();

      /// Wraps the message in an XML stream using the `_streamWrap` method.
      final string = _streamWrap(message);

      /// Parses the wrapped message as an XML document.
      final element = xml.XmlDocument.parse(string);
      connection.connectCB(element.rootElement, null, message);
    }
  }

  /// Called on stream start/restart when no `stream:features` has been
  /// received.
  ///
  /// * @param callback The callback to be called when the authentication
  /// is not supported.
  @override
  void nonAuth([void Function(Echo)? callback]) {
    /// Log error message.
    Log().error('Server did not offer a supported authentication mechanism');

    /// Change the status to the not supported authentication mechanism.
    connection.changeConnectStatus(
      Status.connfail,
      errorCondition['NO_AUTH_MECH'],
    );

    /// If the callback param is not null, then run this callback.
    if (callback != null) {
      callback.call(connection);
    }

    /// Lastly, disconnect from the current connection.
    connection.doDisconnect();
  }

  /// Disconnects the socket connection and performs necessary cleanup actions.
  ///
  /// Accepts only a parameter representing the presence to be sent before
  /// disconnecting.
  @override
  void disconnect([xml.XmlElement? presence]) {
    /// Check if the socket is not null and its state is not equal to 3 (closed).
    if (socket != null && socket!.readyState != 3) {
      /// If presence is provided, send the presence using the connection.
      // if (presence != null) {
      //   connection.send(presence: presence);
      // }

      /// Create a 'close' XML element using [EchoBuilder] with 'xlmns'
      /// attribute.
      final close = EchoBuilder('close', {'xlmns': ns['FRAMING']});

      /// Send the XML tree representation of the 'close' element using
      /// connection's `xmlOutput`.
      connection.xmlOutput(close.nodeTree);

      /// Serialize the 'close' node tree to a string.
      final closeString = Utils.serialize(close.nodeTree);

      /// Send the serialized 'close' string using connection's `rawOutput`.
      connection.rawOutput(closeString);
      try {
        /// Add the 'close' string to the socket.
        socket!.add(closeString);
      } catch (_) {
        /// Log a warning if adding the 'close' string to the socket fails.
        Log().warn('Could not send <close /> tag.');
      }
    }
    return connection.doDisconnect();
  }

  /// Just closes the Socket.
  @override
  void doDisconnect() {
    /// Informs user about the method call.
    Log().info("WebSocket's doDisconnect method is called.");

    /// And calls close socket for returning to the initial state.
    _closeSocket();
  }

  /// Helper function to wrap a stanza in a <stream> tag.
  ///
  /// This is used, so [Echo] can process stanzas from Websockets like BOSH.
  String _streamWrap(String stanza) => '<wrapper>$stanza</wrapper>';

  /// Replaces the message handler callback with the default message handling
  /// method.
  ///
  /// This method assigns the `_onMessage` method as the new message handler
  /// method, due this assign process will take place after initial message
  /// get.
  ///
  /// The `_onMessage` method is responsible for handling incoming messages and
  /// performing any necessary actions or processing.
  void _replaceMessageHandler() => _onMessageCallback = _onMessage;

  /// Function to check if the message queue is empty.
  ///
  /// True, because WebSocket messages are send immediately after queueing.
  bool emptyQueue() {
    return true;
  }

  /// Timeout handler for handling non-graceful disconnecting.
  ///
  /// This does nothing for WebSocket.
  void onDisconnectTimeout() {}

  /// Helper function that makes sure all pending requests are aborted.
  @override
  void abortAllRequests() {}

  /// Handles processing of idle connection state. Sends all queued stanzas.
  ///
  /// This method sends any pending data from the connection when the connection
  /// is idle.
  void onIdle() {
    final data = connection.data;

    /// Check if there is pending data and the connection is not paused.
    if (data!.isNotEmpty && !connection.paused!) {
      for (int i = 0; i < data.length; i++) {
        if (data[i] != null) {
          xml.XmlElement stanza;

          /// Check the type of the data element and build the appropriate XML
          /// stanza
          if (data[i] == 'restart') {
            stanza = _buildStream().nodeTree!;
          } else {
            stanza = data[i] as xml.XmlElement;
          }

          /// Serialize the stanza to a raw string.
          final rawStanza = Utils.serialize(stanza);

          /// Send the stanza using the connection's `xmlOutput` and `rawOutput`
          /// methods.
          connection.xmlOutput(stanza);
          connection.rawOutput(rawStanza);

          /// Add the raw stanza to the socket.
          socket!.add(rawStanza);
        }
      }

      /// Clear the connection's data list after sending all the pending data.
      connection.data = [];
    }
  }

  /// Handles incoming XMPP messages received over the WebSocket connection.
  ///
  /// Accepts [String] type `message` variable, that indicates the message
  /// received over the socket.
  ///
  /// Since all XMPP traffic starts with
  /// ```xml
  ///  <stream:stream version='1.0'
  ///                 xml:lang='en'
  ///                 xmlns='jabber:client'
  ///                 xmlns:stream='http://etherx.jabber.org/streams'
  ///                 id='3697395463'
  ///                 from='SERVER'>
  /// ```
  /// The first stanza will always fail to be parsed.
  void _onMessage(String message) {
    /// Decleration of [xml.XmlElement] for later use.
    xml.XmlElement? element;

    /// Check for closing stream.
    const close = '<close xmlns="urn:ietf:params:xml:ns:xmpp-framing" />';

    /// Starts by checking if the message represents a closing stream.
    ///
    /// If the message is a closing stream message, it notifies the connection,
    /// updates the input logs, and disconnects if the connection is in the
    /// disconnecting state.
    if (message == close) {
      /// Update raw input logs
      connection.rawInput(close);

      /// Update xml input log.
      connection.xmlInput(message);

      /// Check if connection is in the `disconnecting` state.
      if (connection.disconnecting!) {
        /// If yes, then disconnect from it.
        connection.doDisconnect();
      } else if (message.contains('<open ')) {
        element = xml.XmlDocument.parse(message).rootElement;
        if (!_handleStreamStart(element)) {
          return;
        }
      } else {
        final data = _streamWrap(message);
        element = xml.XmlDocument.parse(data).rootElement;
      }

      if (_checkStreamError(element!, Status.error)) {
        return;
      }

      if (connection.disconnecting! &&
          element.firstChild!.value == 'presence' &&
          element.firstChild!.getAttribute('type') == 'unavailable') {
        connection.xmlInput(element);
        connection.rawInput(Utils.serialize(element));

        /// If we are already disconnecting we will ignore the unavailable
        /// stanza and wait for the </stream:stream> tag before we close the
        /// connection,
        return;
      }

      connection.dataRecv(element, message);
    }

    /// If the message starts with `<open`, it is parsed into an XML element
    /// using `xml.XmlDocument.parse()`.
    else if (message.startsWith('<open ')) {
      /// Parse element from `message`.
      element = xml.XmlDocument.parse(message).rootElement;

      /// Method is then called to handle the start of the XMPP stream.
      if (!_handleStreamStart(element)) {
        return;
      }
    }

    /// If the message doesn't represent a closing stream or a stream start,
    /// it is wrapped using `_streamWrap` and then parsed into an XML element.
    else {
      final data = _streamWrap(message);
      element = xml.XmlDocument.parse(data).rootElement;
    }

    /// The method checks if there is a stream error by calling
    /// `_checkStreamError`.
    if (_checkStreamError(element, Status.error)) {
      return;
    }

    /// If connection is in disconnecting state, node type is `ELEMENT` and type
    /// is unavailable, then log the last gathered element and exit from the
    /// function.
    if (connection.disconnecting! &&
        element.firstChild!.nodeType == xml.XmlNodeType.ELEMENT &&
        element.firstChild!.getAttribute('type') == 'unavailable') {
      connection.xmlInput(element);
      connection.rawInput(Utils.serialize(element));
      // if we are already disconnecting we will ignore the unavailable stanza and
      // wait for the </stream:stream> tag before we close the connection
      return;
    }

    connection.dataRecv(element, message);
  }

  /// Event handler called when the WebSocket connection is successfully opened.
  ///
  /// This method logs an informational message indicating that the `WebSocket`
  /// is open.
  void _onOpen() {
    /// Before doing other shittos, outputs that the `WebSocket` is working.
    Log().info('Websocket is open');

    /// It creates and sends an initial XMPP stream to the server, using the
    /// `_buildStream` method.
    final start = _buildStream();

    /// The XML representation of the stream is logged using the
    /// `connection.xmlOutput` method.
    connection.xmlOutput(start.nodeTree);

    /// The node tree serialized using [Utils]'s serialize method.
    final startString = Utils.serialize(start.nodeTree);

    /// the serialized string representation is logged using the
    /// `connection.rawOutput` method.
    connection.rawOutput(startString);

    /// Finally, the stream string is sent over the WebSocket connection by
    /// adding it to the socket's buffer.
    socket!.add(startString);
  }

  /// Event handler called when the WebSocket connection is closed.
  ///
  /// This method checks the state of the connection and performs different
  /// actions based on the state.
  void _onClose({int? code}) {
    /// If the connection is currently connected and not in the process of
    /// disconnecting,
    if (connection.connected! && !connection.disconnecting!) {
      connection.doDisconnect();
    }

    /// If the connection is not currently connected, an error message is
    /// logged indicating that the `WebSocket` connection was closed
    /// unexpectedly.
    ///
    /// If closing code is not null and equals to the specific number which
    /// indicates to `1006` in this case, this means that `websocket` is closed
    /// unexpectedly.
    else if (socket != null &&
        code != null &&
        code == 1006 &&
        !connection.connected!) {
      Log().error('Websocket closed unexpectedly.');

      /// The connection status is updated to a connection failure status with
      /// an appropriate error message using the
      /// `connection.changeConnectStatus` method.
      connection.changeConnectStatus(
        Status.connfail,
        'Websocket connection could not be established or was disconnected.',
      );
    } else {
      /// If none of the above conditions are met, an informational message is
      /// logged indicating that the `WebSocket` connection was closed.
      Log().info('Websocket closed');
    }
  }

  /// TODO: Expand this method with the additional `Error` object and error
  /// messages for future updates.
  ///
  /// Event handler called when an error occurs in the `WebSocket` connection.
  ///
  /// This method logs an error message indicating that a `WebSocket` error
  /// occurred.
  ///
  /// It then calls the `connection.changeConnectStatus` method to update the
  /// connection status with a connection failure status and an appropriate
  /// error message.
  void _onError(dynamic error, dynamic trace) {
    /// Logs out error message using [Log].
    Log().error('Websocket error occured');

    /// Changes the status of the connection.
    connection.changeConnectStatus(
      Status.connfail,
      'The websocket connection could not be established or was disconnected.',
    );
  }

  /// Closes the WebSocket connection.
  /// * If a WebSocket connection is currently open, it is closed gracefully.
  /// * If an error occurs during the closing process, an info log is generated.
  /// * After closing the connection, the socket reference is set to null.
  void _closeSocket() {
    if (socket != null) {
      try {
        /// It performs a graceful closing of the connection by calling the
        /// `close()` method on the WebSocket object
        socket!.close();
      } catch (error) {
        /// If an error occurs during the closing process, an info log is
        /// generated with the error message.
        Log().info(error.toString());
      }
    }

    /// After closing the connection, the socket reference is set to null to
    /// indicate that the connection is no longer open.
    socket = null;
  }

  /// Sends any pending data from the connection.
  ///
  /// Just flushes the messages that are in the queue.
  @override
  void send() => connection.flush();

  /// Method to get a stanza out of a request.
  ///
  /// WebSockets do not use requests, so the passed argument is just returned.
  @override
  xml.XmlElement? reqToData(xml.XmlElement? stanza) => stanza;

  /// Send an xmpp:restart stanza.
  @override
  void sendRestart() {}
}
