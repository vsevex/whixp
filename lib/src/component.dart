part of 'whixp.dart';

/// The wire component protocol in use today enables an external component to
/// connect to a server (with proper configuration and authentication) and to
/// send and receive XML stanzas through the server. There are two connection
/// methods: "accept" and "connect". When the "accept" method is used, the
/// server waits for connections from components and accepts them when they are
/// initiated by a component. When the "connect" method is used, the server
/// initiates the connection to a component.
///
/// see <https://xmpp.org/extensions/xep-0114.html>
class WhixpComponent extends WhixpBase {
  /// Basic XMPP server component.
  ///
  /// An external component is called "trusted" because it authenticates with a
  /// server using authentication credentials that include a shared [secret].
  WhixpComponent(
    String jabberID, {
    required String secret,
    super.host,
    super.port,
    super.useTLS,
    super.disableStartTLS,
    super.connectionTimeout,
    super.maxReconnectionAttempt,
    super.onBadCertificateCallback,
    super.certs,
    super.logger,
    super.hivePathName,
    super.provideHivePath,
    bool useClientNamespace = false,
  }) : super(jabberID: jabberID, whitespaceKeepAlive: false) {
    if (useClientNamespace) {
      transport.defaultNamespace = WhixpUtils.getNamespace('CLIENT');
    } else {
      transport.defaultNamespace = WhixpUtils.getNamespace('COMPONENT');
    }

    transport
      ..streamHeader =
          '<stream:stream xmlns="${WhixpUtils.getNamespace('COMPONENT')}" xmlns:stream="$_streamNamespace" to="${transport.boundJID}">'
      ..streamFooter = '</stream:stream>'
      ..sessionStarted = false
      ..startStreamHandler = ([attributes]) {
        if (attributes == null) return;
        for (final attribute in attributes) {
          if (attribute.name == 'id') {
            final sid = attribute.value;
            final prehash = WhixpUtils.stringToArrayBuffer('$sid$secret');

            final handshake = Handshake();
            handshake['value'] = sha1.convert(prehash).toString().toLowerCase();

            transport.send(handshake);
            break;
          }
        }
      };

    transport
      ..registerHandler(
        CallbackHandler(
          'Handshake',
          _handleHandshake,
          matcher: XPathMatcher(
            '{${WhixpUtils.getNamespace('COMPONENT')}}handshake',
          ),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'Handshake',
          _handleHandshake,
          matcher: XPathMatcher(
            '{${WhixpUtils.getNamespace('JABBER_STREAM')}}handshake',
          ),
        ),
      );
    transport.addEventHandler<Presence>('presenceProbe', _handleProbe);
  }

  @override
  bool get isComponent => true;

  /// Connects to the server.
  void connect() => transport.connect();

  /// The Handshake has been accepted.
  void _handleHandshake(StanzaBase? stanza) => transport
    ..sessionBind = true
    ..sessionStarted = true
    ..emit<JabberID>('sessionBind', data: transport.boundJID)
    ..emit('sessionStart');

  void _handleProbe(Presence? presence) {
    if (presence == null) return;
    return ((roster[presence.to.toString()]
            as rost.RosterNode)[presence.from.toString()] as rost.RosterItem)
        .handleProbe();
  }
}
