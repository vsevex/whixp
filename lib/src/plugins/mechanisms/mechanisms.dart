import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// Represents SASL mechanisms.
///
/// This class handles SASL mechanisms supported by the server.
class SASLMechanisms {
  /// The name of the mechanisms.
  static const name = 'mechanisms';

  /// Constructs a [SASLMechanisms] instance.
  SASLMechanisms();

  /// List of supported mechanisms.
  final list = <String>{};

  /// Constructs a [SASLMechanisms] instance from XML.
  factory SASLMechanisms.fromXML(xml.XmlElement node) {
    final mechanisms = SASLMechanisms();

    for (final child in node.children.whereType<xml.XmlElement>()) {
      switch (child.localName) {
        case 'mechanism':
          mechanisms.list.add(child.innerText);
      }
    }

    return mechanisms;
  }

  /// Converts [SASLMechanisms] instance to XML.
  xml.XmlElement toXML() {
    final element = WhixpUtils.xmlElement(
      name,
      namespace: 'urn:ietf:params:xml:ns:xmpp-sasl',
    );

    for (final mech in list) {
      element.children.add(
        xml.XmlElement(
          xml.XmlName('mechanism'),
          [],
          [xml.XmlText(mech).copy()],
        ),
      );
    }

    return element;
  }
}
