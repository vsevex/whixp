import 'package:dartz/dartz.dart';

import 'package:echox/src/echotils/src/echotils.dart';

import 'package:xml/xml.dart' as xml;

class XMLBase {
  XMLBase({
    xml.XmlElement? element,
    Either<WeakReference<XMLBase>, XMLBase>? parent,
  }) {
    name = 'stanza';
    namespace = Echotils.getNamespace('CLIENT');
    if (element != null) {
      this.element = element;
    }

    if (parent != null) {
      parent.fold(
        (reference) => this.parent = reference.target,
        (parent) => this.parent = parent,
      );
    }

    /// If XML generated, then everything is ready.
    if (setup(element)) {
      return;
    }
  }

  /// The XML tag name of the element, not including any namespace prefixes.
  late final String name;

  /// The XML namespace for the element. Given `<foo xmlns="bar" />`, then
  /// `namespace = "bar"` should be used.
  ///
  /// Defaults namespace in the constructor scope to `jabber:client` since this
  /// is being used in an XMPP library.
  late String namespace;

  /// The set of keys that the stanza provides for accessing and manipulating
  /// the underlying XML object.
  final interfaces = <String>{'type', 'to', 'from', 'id', 'payload'};
  xml.XmlElement? element;
  XMLBase? parent;

  bool setup([xml.XmlElement? element]) {
    if (element != null && element != this.element) {
      this.element = element;
      return false;
    }

    if (element != null) {
      return false;
    }

    if (this.element != null) {
      return false;
    }

    for (final ename in name.split('/')) {
      final newXML = xml.XmlElement(xml.XmlName('$namespace$ename'));
      if (this.element == null) {
        this.element = newXML;
      } else {
        this.element!.children.add(newXML);
      }
    }

    if (parent != null) {
      if (parent!.element != null) {
        parent!.element!.children.add(parent!.element!);
      }
    }

    return true;
  }
}
