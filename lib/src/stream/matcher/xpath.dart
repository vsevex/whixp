import 'package:echox/src/stream/base.dart';
import 'package:echox/src/stream/matcher/base.dart';

class XPathMatcher extends BaseMatcher {
  XPathMatcher(super.criteria);

  /// Compare a stanza against a "stanza path". A stanza path is similar to an
  /// XPath expression, but uses the stanza's interfaces and plugins instead of
  /// the underlying XML.
  @override
  bool match(XMLBase base) {
    final element = base.element;

    String tag() =>
        '<${element!.localName} xmlns="${element.getAttribute('xmlns')}"/>';

    return criteria == tag();
  }
}
