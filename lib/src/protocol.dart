import 'package:echo/src/echo.dart';

import 'package:xml/xml.dart' as xml;

/// An abstract class that represents a protocol used by this client.
abstract class Protocol {
  /// A nullable [String] that represents the strip value.
  String? strip;

  void reset();

  /// Establishes a connection using the specified protocol.
  ///
  /// This method establishes a connection (e.g. WebSocket) using the service
  /// URL and the 'xmpp' protocol. It closes any existing connection before
  /// creating a new one. Once the connection is established, it listens for
  /// incoming messages on the protocol.
  Future<void> connect();

  /// Callback method which is invoked upon a successful connection.
  ///
  /// Accepts a parameter named `bodyWrap` which represents the body wrap.
  Future<int> connectCB(xml.XmlElement bodyWrap);

  /// This method is used to disconnect the protocol connection. If a
  /// `presence` element is provided, it is used to send the connection
  /// associated with the protocol.
  Future<void> disconnect([xml.XmlElement? presence]);

  /// This method is used to disconnect the protocol.
  ///
  /// Performs the disconnection of the protocol.
  Future<void> doDisconnect();

  /// This method is used to send any pending data to the connection. The
  /// exact implementation of this method may vary depending on the concrete
  /// protocol implementation. In the case of WebSocket, it just flushes the
  /// queue.
  void send();

  /// Performs a non-authenticated operation.
  ///
  /// This method is called when the server does not offer a supported
  /// authentication method.
  Future<void> nonAuth([Future<void> Function(Echo)? function]);

  /// Handles processing of the idle connection state by sending all queued
  /// stanzas.
  ///
  /// This method is responsible for handling the processing of the idle
  /// connection state. It sends any pending data from the connection when the
  /// connection is idle. The exact implementation may vary depending on the
  /// concrete implementation of the protocol.
  void onIdle();
  void abortAllRequests();
  xml.XmlElement? reqToData(xml.XmlElement? stanza);
  void sendRestart();
}
