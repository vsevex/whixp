// IMPORTED FROM `strophe.js` project. (https://github.com/strophe/strophejs/blob/master/src/constants.js)
//
// DO NOT MODIFY BY HAND.

/// ### Common namespace constants from the XMPP RFCs and XEPs
///
/// Constants: XMPP Namespace Constants
///
/// Common namespace constants from the XMPP RFCs and XEPs.
///
/// * _ns[HTTPBIND]_ - HTTP BIND namespace from XEP 124.
/// * _ns[BOSH]_ - BOSH namespace from XEP 206.
/// * _ns[CLIENT]_ - Main XMPP client namespace.
/// * _ns[AUTH]_ - Legacy authentication namespace.
/// * _ns[ROSTER]_ - Roster operations namespace.
/// * _ns[PROFILE]_ - Profile namespace.
/// * _ns[DISCO_INFO]_ - Service discovery info namespace from XEP 30.
/// * _ns[DISCO_ITEMS]_ - Service discovery items namespace from XEP 30.
/// * _ns[MUC]_ - Multi-User Chat namespace from XEP 45.
/// * _ns[SASL]_ - XMPP SASL namespace from RFC 3920.
/// * _ns[STREAM]_ - XMPP Streams namespace from RFC 3920.
/// * _ns[BIND]_ - XMPP Binding namespace from RFC 3920 and RFC 6120.
/// * _ns[SESSION]_ - XMPP Session namespace from RFC 3920.
/// * _ns[XHTML_IM]_ - XHTML-IM namespace from XEP 71.
/// * _ns[XHTML]_ - XHTML body namespace from XEP 71.
const ns = <String, String>{
  'HTTPBIND': "http://jabber.org/protocol/httpbind",
  'BOSH': "urn:xmpp:xbosh",
  'CLIENT': "jabber:client",
  'AUTH': "jabber:iq:auth",
  'ROSTER': "jabber:iq:roster",
  'PROFILE': "jabber:iq:profile",
  'DISCO_INFO': "http://jabber.org/protocol/disco#info",
  'DISCO_ITEMS': "http://jabber.org/protocol/disco#items",
  'MUC': "http://jabber.org/protocol/muc",
  'SASL': "urn:ietf:params:xml:ns:xmpp-sasl",
  'STREAM': "http://etherx.jabber.org/streams",
  'FRAMING': "urn:ietf:params:xml:ns:xmpp-framing",
  'BIND': "urn:ietf:params:xml:ns:xmpp-bind",
  'SESSION': "urn:ietf:params:xml:ns:xmpp-session",
  'VERSION': "jabber:iq:version",
  'STANZAS': "urn:ietf:params:xml:ns:xmpp-stanzas",
  'XHTML_IM': "http://jabber.org/protocol/xhtml-im",
  'XHTML': "http://www.w3.org/1999/xhtml",
};

/// ### XHTML_IN Namespace
///
/// Contains allowed tags, tag attributes, and css properties.
///
/// Used in the createHtml function to filter incoming html into the allowed
/// XHTML-IM subset.
///
/// NOTE: See http://xmpp.org/extensions/xep-0071.html#profile-summary for the
/// list of recommended allowed tags and their attributes.

const xhtml = <String, dynamic>{
  'tags': <String>[
    'a',
    'blockquote',
    'br',
    'cite',
    'em',
    'img',
    'li',
    'ol',
    'p',
    'span',
    'strong',
    'ul',
    'body'
  ],
  'attributes': <String, List<String>>{
    'a': ['href'],
    'blockquote': ['style'],
    'br': [],
    'cite': ['style'],
    'em': [],
    'img': ['src', 'alt', 'style', 'height', 'width'],
    'li': ['style'],
    'ol': ['style'],
    'p': ['style'],
    'span': ['style'],
    'strong': [],
    'ul': ['style'],
    'body': []
  },
  'css': <String>[
    'background-color',
    'color',
    'font-family',
    'font-size',
    'font-style',
    'font-weight',
    'margin-left',
    'margin-right',
    'text-align',
    'text-decoration'
  ],
};

/// All possible statuses enumerated, for further information please refer to
/// `status` constant.
enum Status {
  error,
  connecting,
  connfail,
  authenticating,
  authFail,
  connected,
  disconnected,
  disconnecting,
  attached,
  redirect,
  connTimeout,
  bindRequired,
  attachFail
}

/// ### Connection status constants
///
/// Connection status constants for use by the connection handler callback.
///
/// * _status[ERROR]_ - An error has occurred.
/// * _status[CONNECTING]_ - The connection is currently being made.
/// * _status[CONNFAIL]_ - The connection attempt failed.
/// * _status[AUTHENTICATING]_ - The connection is authenticating.
/// * _status[AUTHFAIL]_ - The authentication attempt failed.
/// * _status[CONNECTED]_ - The connection has succeeded.
/// * _status[DISCONNECTED]_ - The connection has been terminated.
/// * _status[DISCONNECTING]_ - The connection is currently being terminated.
/// * _status[ATTACHED]_ - The connection has been attached.
/// * _status[REDIRECT]_ - The connection has been redirected.
/// * _status[CONNTIMEOUT]_ - The connection has timed out.
const status = <Status, int>{
  Status.error: 0,
  Status.connecting: 1,
  Status.connfail: 2,
  Status.authenticating: 3,
  Status.authFail: 4,
  Status.connected: 5,
  Status.disconnected: 6,
  Status.disconnecting: 7,
  Status.attached: 8,
  Status.redirect: 9,
  Status.connTimeout: 10,
  Status.bindRequired: 11,
  Status.attachFail: 12,
};

const errorCondition = {
  'BAD_FORMAT': 'bad-format',
  'CONFLICT': 'conflict',
  'MISSING_JID_NODE': "x-strophe-bad-non-anon-jid",
  'NO_AUTH_MECH': "no-auth-mech",
  'UNKNOWN_REASON': "unknown",
};

/// __Timeout multiplier__. A waiting request will be considered failed after
/// `Math.floor(timeout * wait)` seconds have elapsed. This defaults to `1.1`,
/// and with default wait, `66` seconds.
const timeout = 1.1;

/// __SecondaryTimeout multiplier__. In cases where `Echo` can detect early
/// failure, it will consider the request failed if it does not return after
/// `Math.floor(secondaryTimeout * wait)` seconds have elapsed. This defaults
/// to `0.1`, and with default wait, `6` seconds.
const secondaryTimeout = .1;
