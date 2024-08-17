import 'package:whixp/src/_static.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// Represents an XMPP version IQ stanza.
///
/// This stanza is typically used to query for information about the software
/// version of an XMPP entity.
///
/// Example usage:
/// ```xml
/// <iq type="get" to="example.com" id="version_1">
///   <query xmlns="jabber:iq:version"/>
/// </iq>
/// ```
class Version extends IQStanza {
  static const String _namespace = 'jabber:iq:version';
  static const String _name = 'query';

  /// Constructs a version IQ stanza.
  const Version({this.versionName, this.version, this.os});

  /// The name of the software version.
  final String? versionName;

  /// The version of the software.
  final String? version;

  /// The operating system information.
  final String? os;

  /// Constructs a version IQ stanza from an XML element node.
  factory Version.fromXML(xml.XmlElement node) {
    String? versionName;
    String? version;
    String? os;

    for (final child in node.children.whereType<xml.XmlElement>()) {
      switch (child.localName) {
        case 'name':
          versionName = child.innerText;
        case 'version':
          version = child.innerText;
        case 'os':
          os = child.innerText;
      }
    }

    return Version(versionName: versionName, version: version, os: os);
  }

  /// Converts the version IQ stanza to its XML representation.
  @override
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();

    builder.element(
      name,
      nest: () {
        if (versionName?.isNotEmpty ?? false) {
          builder.element('name', nest: () => builder.text(versionName!));
        }
        if (version?.isNotEmpty ?? false) {
          builder.element('version', nest: () => builder.text(version!));
        }
        if (os?.isNotEmpty ?? false) {
          builder.element('os', nest: () => builder.text(os!));
        }
      },
    );

    return builder.buildDocument().rootElement
      ..setAttribute('xmlns', namespace);
  }

  /// Sets the information for the software version.
  Version setInfo({String? name, String? version, String? os}) =>
      Version(versionName: name, version: version, os: os);

  /// Returns the name of the version IQ stanza.
  @override
  String get name => _name;

  /// Returns the namespace of the version IQ stanza.
  @override
  String get namespace => _namespace;

  @override
  String get tag => versionTag;
}
