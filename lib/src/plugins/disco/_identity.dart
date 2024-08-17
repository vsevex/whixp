part of 'info.dart';

/// Represents an XMPP identity.
///
/// Identity is typically used to describe the identity of an XMPP entity,
/// providing information such as name, category, and type.
///
/// Example usage:
/// ```xml
/// <identity name="Conference Service" category="conference" type="text"/>
/// ```
class Identity {
  static const _name = 'identity';

  /// Constructs an identity.
  Identity({this.name, this.category, this.type});

  /// The name of the identity.
  final String? name;

  /// The category of the identity.
  final String? category;

  /// The type of the identity.
  final String? type;

  /// Constructs an identity from an XML element node.
  ///
  /// Throws [WhixpInternalException] if the provided XML node is invalid.
  factory Identity.fromXML(xml.XmlElement node) {
    if (_name != node.localName) {
      throw WhixpInternalException.invalidNode(node.localName, _name);
    }

    String? name;
    String? category;
    String? type;

    for (final attribute in node.attributes) {
      switch (attribute.localName) {
        case 'name':
          name = attribute.value;
        case 'category':
          category = attribute.value;
        case 'type':
          type = attribute.value;
      }
    }
    return Identity(name: name, category: category, type: type);
  }

  /// Converts the identity to its XML representation.
  xml.XmlElement toXML() {
    final dictionary = HashMap<String, String>();
    if (name?.isNotEmpty ?? false) {
      dictionary['name'] = name!;
    }
    if (category?.isNotEmpty ?? false) {
      dictionary['category'] = category!;
    }
    if (type?.isNotEmpty ?? false) {
      dictionary['type'] = type!;
    }
    final builder = WhixpUtils.makeGenerator()
      ..element(_name, attributes: dictionary);
    return builder.buildDocument().rootElement;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Identity &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          category == other.category &&
          type == other.type;

  @override
  int get hashCode => name.hashCode ^ category.hashCode ^ type.hashCode;
}
