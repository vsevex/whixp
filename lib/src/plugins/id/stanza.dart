part of 'id.dart';

class StanzaID extends MessageStanza {
  const StanzaID(this.id, {this.by});

  final String id;
  final JabberID? by;

  @override
  xml.XmlElement toXML() {
    final attributes = <String, String>{};
    attributes['id'] = id;
    if (by != null) attributes['by'] = by.toString();

    return WhixpUtils.xmlElement(
      name,
      namespace: 'urn:xmpp:sid:0',
      attributes: attributes,
    );
  }

  /// Constructs a [SASLSuccess] packet from XML.
  factory StanzaID.fromXML(xml.XmlElement node) {
    late String id;
    JabberID? by;

    for (final attribute in node.attributes) {
      switch (attribute.localName) {
        case 'id':
          id = attribute.value;
        case 'by':
          by = JabberID(attribute.value);
      }
    }

    return StanzaID(id, by: by);
  }

  @override
  String get name => 'stanza-id';

  @override
  String get tag => stanzaIDTag;
}

class OriginID extends MessageStanza {
  const OriginID(this.id);

  final String id;

  @override
  xml.XmlElement toXML() {
    final attributes = <String, String>{};
    attributes['id'] = id;

    return WhixpUtils.xmlElement(
      'success',
      namespace: 'urn:xmpp:sid:0',
      attributes: attributes,
    );
  }

  /// Constructs a [SASLSuccess] packet from XML.
  factory OriginID.fromXML(xml.XmlElement node) {
    late String id;

    for (final attribute in node.attributes) {
      switch (attribute.localName) {
        case 'id':
          id = attribute.value;
      }
    }

    return OriginID(id);
  }

  @override
  String get name => 'origin-id';

  @override
  String get tag => originIDTag;
}
