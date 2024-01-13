part of 'ping.dart';

/// Given that XMPP is reliant on TCP connections, the underlying connection may
/// be canceled without the application's knowledge. For identifying broken
/// connections, ping stanzas are an alternative to whitespace-based keepalive
/// approaches.
@internal
class PingStanza extends XMLBase {
  /// ```xml
  /// ping
  /// <iq from='vsevex@example.com' to='alyosha@example.com/desktop' id='c2c1' type='get'>
  ///   <ping xmlns='urn:xmpp:ping'/>
  /// </iq>
  ///
  /// pong
  /// <iq from='alyosha@example.com/desktop' to='vsevex@example.com' id='c2c1' type='result'/>
  /// ```
  PingStanza()
      : super(
          name: 'ping',
          namespace: 'urn:xmpp:ping',
          pluginAttribute: 'ping',
        );
}
