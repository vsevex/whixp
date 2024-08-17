part of 'items.dart';

/// Represents an XMPP disco item.
///
/// Disco items are used in service discovery to represent items associated
/// with a particular node.
///
/// Example usage:
/// ```xml
/// <item jid="room@example.com" name="Room" node="conference"/>
/// ```
class DiscoItem {
  static const _name = 'item';

  /// Constructs a disco item.
  DiscoItem({this.jid, this.node, this.name});

  /// The JID associated with the disco item.
  final String? jid;

  /// The node associated with the disco item.
  final String? node;

  /// The name of the disco item.
  final String? name;

  /// Constructs a disco item from an XML element node.
  ///
  /// Throws [WhixpInternalException] if the provided XML node is invalid.
  factory DiscoItem.fromXML(xml.XmlElement node) {
    if (_name != node.localName) {
      throw WhixpInternalException.invalidNode(node.localName, _name);
    }

    String? jid;
    String? nod;
    String? name;

    for (final attribute in node.attributes) {
      switch (attribute.localName) {
        case 'jid':
          jid = attribute.value;
        case 'node':
          nod = attribute.value;
        case 'name':
          name = attribute.value;
      }
    }
    return DiscoItem(jid: jid, node: nod, name: name);
  }

  /// Converts the disco item to its XML representation.
  xml.XmlElement toXML() {
    final dictionary = HashMap<String, String>();
    final builder = WhixpUtils.makeGenerator();
    if (jid?.isNotEmpty ?? false) {
      dictionary['jid'] = jid!;
    }
    if (node?.isNotEmpty ?? false) {
      dictionary['node'] = node!;
    }
    if (name?.isNotEmpty ?? false) {
      dictionary['name'] = name!;
    }
    builder.element(_name, attributes: dictionary);
    return builder.buildDocument().rootElement;
  }
}
