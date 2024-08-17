import 'dart:collection';

import 'package:whixp/src/_static.dart';
import 'package:whixp/src/exception.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

part '_feature.dart';
part '_identity.dart';

final String _namespace = WhixpUtils.getNamespace('DISCO_INFO');

/// Represents an XMPP disco information IQ stanza.
///
/// Disco information IQ stanzas are used for querying and discovering
/// information about an XMPP entity's capabilities and features.
class DiscoInformation extends IQStanza {
  static const String _name = 'query';

  /// Constructs a disco information IQ stanza.
  DiscoInformation({this.node});

  /// The node associated with the disco information.
  final String? node;

  /// List of identities associated with the disco information.
  final identities = <Identity>[];

  /// List of features associated with the disco information.
  final features = <Feature>[];

  /// Constructs a disco information IQ stanza from an XML element node.
  ///
  /// Throws a [WhixpInternalException] if the provided XML node is invalid.
  factory DiscoInformation.fromXML(xml.XmlElement node) {
    if (node.localName != _name) {
      throw WhixpInternalException.invalidNode(node.localName, _name);
    }

    String? nod;
    for (final attribute in node.attributes) {
      switch (attribute.localName) {
        case 'node':
          nod = attribute.value;
      }
    }

    final info = DiscoInformation(node: nod);

    for (final child in node.children.whereType<xml.XmlElement>()) {
      switch (child.localName) {
        case 'identity':
          info.identities.add(Identity.fromXML(child));
        case 'feature':
          info.features.add(Feature.fromXML(child));
      }
    }

    return info;
  }

  /// Converts the disco information IQ stanza to its XML representation.
  @override
  xml.XmlElement toXML() {
    final dictionary = HashMap<String, String>();
    final builder = WhixpUtils.makeGenerator();
    dictionary['xmlns'] = namespace;
    if (node?.isNotEmpty ?? false) {
      dictionary['node'] = node!;
    }

    builder.element(_name, attributes: dictionary);
    final root = builder.buildDocument().rootElement;

    if (identities.isNotEmpty) {
      for (final child in identities) {
        root.children.add(child.toXML().copy());
      }
    }

    if (features.isNotEmpty) {
      for (final feature in features) {
        root.children.add(feature.toXML().copy());
      }
    }

    return root;
  }

  /// Adds an identity to the disco information.
  void addIdentity(String name, String category, {String? type}) {
    int? index;
    if (identities.where((identity) => identity.name == name).isNotEmpty) {
      index = identities.indexWhere((identity) => identity.name == name);
    }
    final identity = Identity(name: name, category: category, type: type);
    if (index != null) {
      identities[index] = identity;
      return;
    }
    identities.add(identity);
  }

  /// Adds features to the disco information.
  void addFeature(List<String> namespaces) {
    for (final namespace in namespaces) {
      features.add(Feature(variable: namespace));
    }
  }

  @override
  String get name => _name;

  @override
  String get namespace => _namespace;

  @override
  String get tag => discoInformationTag;
}
