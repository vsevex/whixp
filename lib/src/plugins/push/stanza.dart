part of 'push.dart';

/// Represents an IQ stanza used to enable push notifications for a specific
/// Jabber ID (JID) and node.
///
/// ```dart
/// final xml = enableStanza.toXML();
/// ```
class Enable extends IQStanza {
  const Enable(this.jid, this.node, {this.payload});

  final JabberID jid;
  final String node;
  final Form? payload;

  @override
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();

    builder.element(
      name,
      attributes: <String, String>{
        'xmlns': namespace,
        'jid': jid.toString(),
        'node': node,
      },
    );

    final element = builder.buildDocument().rootElement;
    if (payload != null) element.children.add(payload!.toXML());

    return element;
  }

  @override
  String get name => 'enable';

  @override
  String get namespace => 'urn:xmpp:push:0';

  @override
  String get tag => enableTag;
}

/// Represents an IQ stanza used to disable push notifications for a specific
/// Jabber ID (JID).
class Disable extends IQStanza {
  const Disable(this.jid, {this.node});

  final JabberID jid;
  final String? node;

  @override
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();
    final attributes = <String, String>{};

    attributes['jid'] = jid.toString();
    if (node?.isNotEmpty ?? false) attributes['node'] = node!;

    builder.element(
      name,
      attributes: <String, String>{'xmlns': namespace}..addAll(attributes),
    );

    return builder.buildDocument().rootElement;
  }

  factory Disable.fromXML(xml.XmlElement node) {
    String? jid;
    String? nod;

    for (final attribute in node.attributes) {
      switch (attribute.localName) {
        case 'jid':
          jid = attribute.value;
        case 'node':
          nod = attribute.value;
        default:
          break;
      }
    }

    return Disable(JabberID(jid), node: nod);
  }

  @override
  String get name => 'disable';

  @override
  String get namespace => 'urn:xmpp:push:0';

  @override
  String get tag => disableTag;
}
