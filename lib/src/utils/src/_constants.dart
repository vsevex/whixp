part of 'utils.dart';

/// ### Common namespace constants from the XMPP RFCs and XEPs
/// * _[ATOM] - Atom Syndication Format namespae from RFC 4287.
/// * _[HTTPBIND]_ - HTTP BIND namespace from XEP-0124.
/// * _[CLIENT]_ - Main XMPP client namespace.
/// * _[AUTH]_ - Legacy authentication namespace.
/// * _[ROSTER]_ - Roster operations namespace.
/// * _[PROFILE]_ - Profile namespace.
/// * _[PREAPPROVAL] - Features Pre-Approval namespace.
/// * _[COMPONENT]_ - Jabber Component Accept namespace.
/// * _[DISCO_INFO]_ - Service discovery info namespace from XEP-0030.
/// * _[DISCO_ITEMS]_ - Service discovery items namespace from XEP-0030.
/// * _[MUC]_ - Multi-User Chat namespace from XEP-0045.
/// * _[SASL]_ - XMPP SASL namespace from RFC 3920.
/// * _[STREAM]_ - XMPP Streams namespace from RFC 3920.
/// * _[FORMS]_ - XMPP Forms namespace.
/// * _[BIND]_ - XMPP Binding namespace from RFC 3920 and RFC 6120.
/// * _[RSM]_ - Result Set Management namespace.
/// * _[MAM]_ - Message Archive Management
/// * _[STARTTLS]_ - XMPP StartTLS namespace.
/// * _[SESSION]_ - XMPP Session namespace from RFC 3920.
/// * _[VER]_ - Roster Versioning namespace.
/// * _[VERSION]_ - XMPP Version namespace.
/// * _[STANZAS]_ - XMPP Stanzas namespace.
final _namespace = <String, String>{
  'ATOM': "http://www.w3.org/2005/Atom",
  'HTTPBIND': "http://jabber.org/protocol/httpbind",
  'CLIENT': "jabber:client",
  'AUTH': "jabber:iq:auth",
  'ROSTER': "jabber:iq:roster",
  'PROFILE': "jabber:iq:profile",
  'PREAPPROVAL': "urn:xmpp:features:pre-approval",
  'COMPONENT': 'jabber:component:accept',
  'DISCO_INFO': "http://jabber.org/protocol/disco#info",
  'DISCO_ITEMS': "http://jabber.org/protocol/disco#items",
  'MUC': "http://jabber.org/protocol/muc",
  'SASL': "urn:ietf:params:xml:ns:xmpp-sasl",
  'STREAM': "urn:ietf:params:xml:ns:xmpp-streams",
  'FORMS': "jabber:x:data",
  'PUBSUB': "http://jabber.org/protocol/pubsub",
  'JABBER_STREAM': "http://etherx.jabber.org/streams",
  'FRAMING': "urn:ietf:params:xml:ns:xmpp-framing",
  'BIND': "urn:ietf:params:xml:ns:xmpp-bind",
  'RSM': "http://jabber.org/protocol/rsm",
  'MAM': "urn:xmpp:mam:2",
  'STARTTLS': "urn:ietf:params:xml:ns:xmpp-tls",
  'SESSION': "urn:ietf:params:xml:ns:xmpp-session",
  'MARKERS': "urn:xmpp:chat-markers:0",
  'VER': "urn:xmpp:features:rosterver",
  'VERSION': "jabber:iq:version",
  'STANZAS': "urn:ietf:params:xml:ns:xmpp-stanzas",
  'XML': "http://www.w3.org/XML/1998/namespace",
  // XEP-0430 Inbox (current namespace)
  // Note: Some servers (e.g. older MongooseIM deployments) used
  // "erlang-solutions.com:xmpp:inbox:0". Parsing code supports both.
  'INBOX': "urn:xmpp:inbox:1",
};
