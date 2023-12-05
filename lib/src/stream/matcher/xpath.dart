import 'package:echox/src/stream/base.dart';
import 'package:echox/src/stream/matcher/base.dart';

import 'package:xml/xml.dart' as xml;

class XPathMatcher extends BaseMatcher {
  XPathMatcher(super.criteria);

  /// Compare a stanza against a "stanza path". A stanza path is similar to an
  /// XPath expression, but uses the stanza's interfaces and plugins instead of
  /// the underlying XML.
  @override
  bool match(XMLBase base) {
    final element = base.element;
    final x = xml.XmlElement(xml.XmlName('x'));
    x.children.add(element!);

    return x.getElement(fixNamespace(criteria as String).value1!) != null;
  }
}
