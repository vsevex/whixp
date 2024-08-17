part of 'info.dart';

/// Represents an XMPP feature.
///
/// Features are typically used to indicate capabilities or supported
/// functionalities by an XMPP entity.
///
/// Example usage:
/// ```xml
/// <feature var="urn:xmpp:ping"/>
/// ```
class Feature {
  static const String _name = 'feature';

  /// Constructs a `feature`.
  Feature({this.variable});

  /// The variable associated with the feature.
  final String? variable;

  /// Constructs a feature from an XML element node.
  ///
  /// Throws [WhixpInternalException] if the provided XML node is invalid.
  factory Feature.fromXML(xml.XmlElement node) {
    if (_name != node.localName) {
      throw WhixpInternalException.invalidNode(node.localName, _name);
    }

    String? variable;

    for (final attribute in node.attributes) {
      switch (attribute.localName) {
        case 'var':
          variable = attribute.value;
      }
    }

    return Feature(variable: variable);
  }

  /// Converts the feature to its XML representation.
  xml.XmlElement toXML() {
    final dictionary = HashMap<String, String>();

    if (variable?.isNotEmpty ?? false) dictionary['var'] = variable!;

    final builder = WhixpUtils.makeGenerator()
      ..element(_name, attributes: dictionary);

    return builder.buildDocument().rootElement;
  }
}
