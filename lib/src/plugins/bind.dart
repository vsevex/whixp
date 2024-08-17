import 'package:whixp/src/_static.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

final _namespace = WhixpUtils.getNamespace('BIND');

/// Represents a Bind IQ stanza used in XMPP communication.
class Bind extends IQStanza {
  /// The name of the Bind stanza.
  static const String _name = 'bind';

  /// Constructor for creating a Bind instance.
  const Bind({this.resource, this.jid});

  /// The resource associated with the Bind stanza.
  final String? resource;

  /// The JID (Jabber Identifier) associated with the Bind stanza.
  final String? jid;

  /// Factory constructor to create a Bind instance from an XML element.
  factory Bind.fromXML(xml.XmlElement node) {
    String? resource;
    String? jid;

    for (final child in node.children.whereType<xml.XmlElement>()) {
      switch (child.localName) {
        case 'resource':
          resource = child.innerText;
        case 'jid':
          jid = child.innerText;
      }
    }

    return Bind(resource: resource, jid: jid);
  }

  @override
  xml.XmlElement toXML() {
    final element = WhixpUtils.makeGenerator();
    element.element(
      name,
      attributes: <String, String>{'xmlns': namespace},
      nest: () {
        if (resource?.isNotEmpty ?? false) {
          element.element('resource', nest: () => element.text(resource!));
        }
        if (jid?.isNotEmpty ?? false) {
          element.element('jid', nest: () => element.text(jid!));
        }
      },
    );

    return element.buildDocument().rootElement;
  }

  @override
  String get name => _name;

  @override
  String get namespace => _namespace;

  @override
  String get tag => bindTag;
}
