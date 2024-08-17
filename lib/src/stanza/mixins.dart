import 'dart:collection';

import 'package:whixp/src/jid/jid.dart';

import 'package:xml/xml.dart' as xml;

/// Represents the type of packet.
enum PacketType { presence, message, iq }

/// Mixin class Packet that provides a common interface for all packet types.
/// This mixin is used to define the basic properties and methods for packets.
mixin Packet {
  /// Property that returns the name of the packet.
  String get name;

  /// Method that converts the packet to an XML element.
  ///
  /// This method is used to serialize the packet into an XML format.
  xml.XmlElement toXML();

  /// Converts the packet to an XML string.
  ///
  /// This method is used to serialize the packet into an XML string format.
  /// It removes the XML declaration and trims the left side of the string.
  String toXMLString() {
    final document = toXML();

    final xmlString = document.toXmlString();
    return xmlString.replaceFirst('<?xml version="1.0"?>', '').trimLeft();
  }

  /// Overrides of the `toString` method to return the XML string representation
  /// of the packet.
  @override
  String toString() => toXMLString();
}

/// Provides a common interface for managing attributes in packets.
///
/// This mixin is used to define the basic properties and methods for handling
/// attributes.
mixin Attributes {
  /// Holds the `XML` namespace of the packet.
  String? _xmlns;

  /// returns the type of the packet. The type is an attribute of the packet
  /// that identifies its type.
  String? type;

  /// The ID is an attribute of the packet that uniquely identifies it.
  String? id;

  /// Returns the sender of the packet. The sender is an attribute of the packet
  /// that identifies who sent it.
  JabberID? from;

  /// Returns the recipient of the packet. The recipient is an attribute of the
  /// packet that identifies who it is intended for.
  JabberID? to;

  /// Returns the language of the packet. The language is an attribute of the
  /// packet that identifies the language used in the packet.
  String? language;

  /// Getter for the `XML` namespace of the packet.
  String? get xmlns => _xmlns;

  /// Setter for the `XML` namespace of the packet.
  set xmlns(String? xmlns) => _xmlns = xmlns;

  /// Loads the attributes of the packet from an `XML` node.
  ///
  /// This method is used to deserialize the packet from an XML format.
  void loadAttributes(xml.XmlNode node) {
    xmlns = node is xml.XmlElement ? node.getAttribute('xmlns') : '';
    for (final attribute in node.attributes) {
      switch (attribute.name.toString()) {
        case "type":
          type = attribute.value;
        case "from":
          from = JabberID(attribute.value);
        case "to":
          to = JabberID(attribute.value);
        case "id":
          id = attribute.value;
        case "lang":
          language = attribute.value;
        default:
          break;
      }
    }
  }

  /// Returns a hash map of the packet's attributes. Serializes the packet into
  /// a hash map format.
  HashMap<String, String> get attributeHash {
    final dictionary = HashMap<String, String>();
    if (_xmlns?.isNotEmpty ?? false) dictionary["xmlns"] = _xmlns!;
    if (id?.isNotEmpty ?? false) dictionary["id"] = id!;
    if (type?.isNotEmpty ?? false) dictionary["type"] = type!;
    if (from != null) dictionary["from"] = from.toString();
    if (to != null) dictionary["to"] = to.toString();
    final langNs = (xmlns?.isNotEmpty ?? false) ? "xml:lang" : "lang";
    if (language?.isNotEmpty ?? false) dictionary[langNs] = language!;

    return dictionary;
  }
}
