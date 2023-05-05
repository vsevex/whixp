import 'package:echo/src/constants.dart';
import 'package:echo/src/utils.dart';

import 'package:xml/xml.dart' as xml;

/// This class represents a builder for creating XML elements using [Utils]
/// helper methods. It provides methods for constructing the XML tree and
/// manipulating the current node.
class EchoBuilder {
  /// Creates a new instance of the [EchoBuilder] class with the given name
  /// and optional attributes.
  EchoBuilder(
    this.name, [
    Map<String, String>? attributes,
  ]) {
    /// Sets correct namespace for jabber:client elements.
    if (name == 'presence' || name == 'message' || name == 'iq') {
      if (attributes != null && !attributes.containsKey('xlmns')) {
        this.attributes!['xlmns'] = ns['CLIENT']!;
      } else if (attributes == null) {
        this.attributes = {'xlmns': ns['CLIENT']!};
      }
    }

    /// Holds the tree being built.
    nodeTree = Utils.xmlElement(name, attributes: this.attributes);

    /// Points to the current operation node.
    node = nodeTree;
  }

  /// [String] representation of the name of an XML element that is being
  /// constructed by the builder.
  final String name;

  /// [Map] representation of attribute key-value pairs for the XML element
  /// being constructed.
  Map<String, String>? attributes;

  xml.XmlNode? nodeTree;
  xml.XmlNode? node;

  /// This function returns a String serialiation of the current DOM tree. It is
  /// often used internally to pass data to a Request object.
  @override
  String toString() => Utils.serialize(nodeTree! as xml.XmlElement)!;

  /// Sets the current node to its parent node.
  void up() => node = node!.parent;

  /// Sets the current node to the root node.
  void root() => node = nodeTree;

  /// Allows for adding or modifying the attributes of the current element.
  /// It takes a [Map] of key-value pairs as an argument, which are iterated
  /// over, and each attribute is either added or modified in the current
  /// element based on whether the key exists or not in the Map.
  void addAttributes(Map<String, String> attributes) {
    /// Iterates all attribute in the attributes [Map].
    for (final attribute in attributes.keys) {
      /// Checks if attributes contain key for verification.
      if (attributes.containsKey(attributes)) {
        if (attributes[attribute] == null) {
          /// If null, then remove attribute from node.
          node!.removeAttribute(attribute);
        } else {
          node!.setAttribute(attribute, attributes[attribute].toString());
        }
      }
    }
  }

  /// Adds a child element to the current element being built. It takes the
  /// child element's name as the first argument and an optional `attributes`
  /// Map and `text` string.
  void c(
    String name, {
    Map<String, String>? attributes,
    String? text,
  }) {
    /// Creates child using `Utils.xmlElement`.
    final child = Utils.xmlElement(name, attributes: attributes, text: text);

    /// Add created child to nodes.
    node!.children.add(child!);
    if (text is! String && text is! num) {
      node = child;
    }
    return;
  }

  /// This method is similar to the method of `c` method, but instead of
  /// passing the name and attributes, it takes an existing `xml.XmlElement`
  /// object and adds it as a child to the current element being built.
  void cnode(xml.XmlElement element) {
    final node = Utils.copyElement(element);
    this.node!.children.add(node);
    this.node = node;
    return;
  }

  /// Add a child text element.
  ///
  /// This does not make the child the new current element since there are no
  /// children of text elements.
  void t(String text) {
    /// Create text node.
    final child = Utils.xmlTextNode(text);

    /// Add created text node to current nodes.
    node!.children.add(child);
    return;
  }
}
