/// Specifies a link relation for selected type of connection.
enum Relation {
  /// Selects link relation attribute as `urn:xmpp:alt-connections:xbosh`.
  bosh('urn:xmpp:alt-connections:xbosh'),

  /// Selects link relation attribute as `urn:xmpp:alt-connections:websocket`.
  websocket('urn:xmpp:alt-connections:websocket');

  /// [String] type attribute that [Relation] type will accept.
  final String attribute;

  /// Constant initializer of [Relation] enumerations.
  const Relation(this.attribute);
}

/// An [HTTPLookup] method is responsible for finding the IP address of a domain
/// name using HTTP protocol. This is done by sending a request to the DNS
/// server, which returns the IP address of the domain name.
///
/// This method uses web host metadata to list the URIs of alternative
/// connection methods.
class HTTPLookup {
  /// Contains namespace that is used to identify documents that contain
  /// information about Web resources.
  static const String xrdNamespace =
      'http://docs.oasis-open.org/ns/xri/xrd-1.0';
}
