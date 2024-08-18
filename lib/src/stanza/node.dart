import 'dart:collection';

import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// Represents an XML node.
class Node {
  /// Constructs an empty XML node.
  Node(this.name, {this.content});

  /// Name of the XML node.
  final String name;

  /// Contents of the XML node.
  final String? content;

  /// List of child nodes.
  late final nodes = <Node>[];

  /// Associated stanzas with the created or parsed node.
  late final stanzas = <Stanza>[];

  /// Attributes associated with the XML node.
  late final attributes = HashMap<String, String>();

  /// Constructs an XML node from an XML element node.
  factory Node.fromXML(xml.XmlElement node) {
    final nod = Node(node.localName, content: node.innerText);

    for (final attribute in node.attributes) {
      nod.attributes[attribute.localName] = attribute.value;
    }

    for (final child in node.children.whereType<xml.XmlElement>()) {
      try {
        final tag = WhixpUtils.generateNamespacedElement(child);
        final stanza = Stanza.payloadFromXML(tag, child);
        nod.stanzas.add(stanza);
      } catch (_) {
        nod.nodes.add(Node.fromXML(child));
      }
    }

    return nod;
  }

  /// Converts the XML node to its XML representation.
  xml.XmlElement toXML() {
    final element = WhixpUtils.xmlElement(xmlName, attributes: attributes);

    if (content?.isNotEmpty ?? false) {
      element.children.add(xml.XmlText(content!));
    }

    if (nodes.isNotEmpty) {
      for (final node in nodes) {
        element.children.add(node.toXML().copy());
      }
    }

    for (final stanza in stanzas) {
      element.children.add(stanza.toXML().copy());
    }

    return element;
  }

  /// Puts the given [stanza] to the list of stanzas.
  void addStanza(Stanza stanza) => stanzas.add(stanza);

  /// Add an attribute [value] with the given [name].
  void addAttribute(String name, [String? value]) {
    if (value?.isEmpty ?? true) return;
    attributes.putIfAbsent(name, () => value!);
  }

  /// Gets stanzas with the given [S] type and the given [name].
  List<S> get<S extends Stanza>(String name) =>
      stanzas.whereType<S>().where((stanza) => stanza.name == name).toList();

  /// Returns the XML name of the node.
  String get xmlName => name;

  @override
  String toString() => toXML().toString();
}

/// Represents a collection of XML nodes.
class Nodes {
  /// Constructs an empty XML nodes.
  Nodes();

  /// List of XML nodes.
  late final List<Node> nodes = [];

  /// Constructs a collection of XML nodes from a list of nodes.
  factory Nodes.fromXML(List<Node> nodes) {
    final nods = Nodes();

    /// Constructs a collection of XML nodes from a list of nodes.
    nodes.whereType<xml.XmlElement>().map((element) {
      if (element.nodeType == xml.XmlNodeType.ELEMENT) {
        nods.nodes.add(Node.fromXML(element));
      }
    });

    return nods;
  }

  /// Converts the collection of XML nodes to its XML representation.
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();
    builder.element(
      'xml',
      nest: () => nodes.map((node) {
        builder.element(
          'node',
          nest: () => builder.text(node.toXML().toString()),
        );
      }),
    );
    return builder.buildDocument().rootElement;
  }
}
