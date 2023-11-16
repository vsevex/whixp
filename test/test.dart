import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/stream/base.dart';

import 'package:xml/xml.dart' as xml;

/// Create and compare several stanza objects to a correct XML string.
void check(String stanza, {String? method = 'exact'}) {}

/// Assign a [namespace] to an element and any children that do not have a
/// namespace.
void fixNamespace(XMLBase base, xml.XmlElement element, [String? namespace]) {
  final ns = namespace ?? Echotils.getNamespace('CLIENT');
  if (element.name.local.startsWith('{')) {
    return;
  }
}
