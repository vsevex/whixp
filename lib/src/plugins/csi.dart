import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/transport.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// It is common for IM clients to be logged in and 'online' even while the user
/// is not interacting with the application. This protocol allows the client to
/// indicate to the server when the user is not actively using the client,
/// allowing the server to optimise traffic to the client accordingly.
///
/// This can save bandwidth and resources on both the client and server.
///
/// For more information: <https://xmpp.org/extensions/xep-0352.html>
class CSI {
  const CSI();

  static void sendInactive() => Transport.instance().send(const CSIInactive());

  static void sendActive() => Transport.instance().send(const CSIActive());
}

class CSIInactive extends Stanza {
  const CSIInactive();

  @override
  xml.XmlElement toXML() =>
      WhixpUtils.xmlElement('inactive', namespace: 'urn:xmpp:csi:0');

  @override
  String get name => 'inactive';
}

class CSIActive extends Stanza {
  const CSIActive();

  @override
  xml.XmlElement toXML() =>
      WhixpUtils.xmlElement('active', namespace: 'urn:xmpp:csi:0');

  @override
  String get name => 'active';
}
