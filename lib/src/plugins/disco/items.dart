import 'dart:collection';

import 'package:whixp/src/_static.dart';
import 'package:whixp/src/exception.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

part '_item.dart';

final _namespace = WhixpUtils.getNamespace('DISCO_ITEMS');

/// Represents an XMPP disco items IQ stanza.
///
/// Disco items IQ stanzas are used for querying and discovering items associated with a particular node.
class DiscoItems extends IQStanza {
  static const _name = 'query';

  /// Constructs a disco items IQ stanza.
  DiscoItems({this.node});

  /// The node associated with the disco items.
  final String? node;

  /// List of disco items associated with the disco items.
  final items = <DiscoItem>[];

  /// Constructs a disco items IQ stanza from an XML element node.
  ///
  /// Throws a [WhixpInternalException] if the provided XML node is invalid.
  factory DiscoItems.fromXML(xml.XmlElement node) {
    String? nod;
    for (final attribute in node.attributes) {
      switch (attribute.localName) {
        case 'node':
          nod = attribute.value;
      }
    }

    final items = DiscoItems(node: nod);

    for (final child in node.children.whereType<xml.XmlElement>()) {
      switch (child.localName) {
        case 'item':
          items.items.add(DiscoItem.fromXML(child));
      }
    }

    return items;
  }

  /// Converts the disco items IQ stanza to its XML representation.
  @override
  xml.XmlElement toXML() {
    final dictionary = HashMap<String, String>();
    dictionary['xmlns'] = namespace;
    if (node?.isNotEmpty ?? false) {
      dictionary['node'] = node!;
    }

    final element = WhixpUtils.xmlElement(
      name,
      attributes: dictionary,
      namespace: namespace,
    );
    for (final item in items) {
      element.children.add(item.toXML().copy());
    }

    return element;
  }

  /// Adds a disco item to the disco items.
  void addItem(String jid, String node, String name) {
    final item = DiscoItem(jid: jid, node: node, name: name);
    items.add(item);
  }

  @override
  String get name => _name;

  @override
  String get namespace => _namespace;

  @override
  String get tag => discoItemsTag;
}
