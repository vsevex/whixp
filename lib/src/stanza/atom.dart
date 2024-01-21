import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// A simple Atom feed entry.
///
/// Atom syndication format:
/// <br><https://datatracker.ietf.org/doc/html/rfc4287>
class AtomEntry extends XMLBase {
  AtomEntry({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.element,
    super.parent,
  }) : super(
          name: 'entry',
          namespace: WhixpUtils.getNamespace('ATOM'),
          pluginAttribute: 'entry',
          interfaces: <String>{
            'title',
            'summary',
            'id',
            'published',
            'updated',
          },
          subInterfaces: <String>{
            'title',
            'summary',
            'id',
            'published',
            'updated',
          },
        ) {
    registerPlugin(AtomAuthor());
  }

  @override
  AtomEntry copy({xml.XmlElement? element, XMLBase? parent}) => AtomEntry(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        element: element,
        parent: parent,
      );
}

/// An Atom author.
class AtomAuthor extends XMLBase {
  AtomAuthor({super.element, super.parent})
      : super(
          name: 'author',
          includeNamespace: false,
          pluginAttribute: 'author',
          interfaces: <String>{'name', 'uri'},
          subInterfaces: <String>{'name', 'uri'},
        );

  @override
  AtomAuthor copy({xml.XmlElement? element, XMLBase? parent}) => AtomAuthor(
        element: element,
        parent: parent,
      );
}
