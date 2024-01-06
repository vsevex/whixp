part of 'utils.dart';

/// ### Common namespace constants from the XMPP RFCs and XEPs
///
/// * _[HTTPBIND]_ - HTTP BIND namespace from XEP 124.
/// * _[CLIENT]_ - Main XMPP client namespace.
/// * _[AUTH]_ - Legacy authentication namespace.
/// * _[ROSTER]_ - Roster operations namespace.
/// * _[PROFILE]_ - Profile namespace.
/// * _[DISCO_INFO]_ - Service discovery info namespace from XEP 30.
/// * _[DISCO_ITEMS]_ - Service discovery items namespace from XEP 30.
/// * _[MUC]_ - Multi-User Chat namespace from XEP 45.
/// * _[SASL]_ - XMPP SASL namespace from RFC 3920.
/// * _[STREAM]_ - XMPP Streams namespace from RFC 3920.
/// * _[BIND]_ - XMPP Binding namespace from RFC 3920 and RFC 6120.
/// * _[SESSION]_ - XMPP Session namespace from RFC 3920.
/// * _[XHTML_IM]_ - XHTML-IM namespace from XEP 71.
/// * _[XHTML]_ - XHTML body namespace from XEP 71.
final _namespace = <String, String>{
  'HTTPBIND': "http://jabber.org/protocol/httpbind",
  'CLIENT': "jabber:client",
  'AUTH': "jabber:iq:auth",
  'ROSTER': "jabber:iq:roster",
  'PROFILE': "jabber:iq:profile",
  'VCARD': "vcard-temp",
  'PREAPPROVAL': "urn:xmpp:features:pre-approval",
  'COMPONENT': 'jabber:component:accept',
  'DISCO_INFO': "http://jabber.org/protocol/disco#info",
  'DISCO_ITEMS': "http://jabber.org/protocol/disco#items",
  'MUC': "http://jabber.org/protocol/muc",
  'SASL': "urn:ietf:params:xml:ns:xmpp-sasl",
  'STREAM': 'urn:ietf:params:xml:ns:xmpp-streams',
  'JABBER_STREAM': "http://etherx.jabber.org/streams",
  'FRAMING': "urn:ietf:params:xml:ns:xmpp-framing",
  'BIND': "urn:ietf:params:xml:ns:xmpp-bind",
  'STARTTLS': "urn:ietf:params:xml:ns:xmpp-tls",
  'SESSION': "urn:ietf:params:xml:ns:xmpp-session",
  'VER': "urn:xmpp:features:rosterver",
  'VERSION': "jabber:iq:version",
  'STANZAS': "urn:ietf:params:xml:ns:xmpp-stanzas",
  'XHTML_IM': "http://jabber.org/protocol/xhtml-im",
  'XHTML': "http://www.w3.org/1999/xhtml",
  'XML': "http://www.w3.org/XML/1998/namespace",
};
