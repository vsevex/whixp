// import 'package:echox/src/stream/base.dart';
import 'package:echox/src/stream/matcher/base.dart';

/// The StanzaPathMatcher selects stanzas that match a given "stanza path",
/// which is similar to a normal `XPath` except that it uses the interfaces and
/// plugins of the stanza instead of the actual, underlying XML.
class StanzaPathMatcher extends BaseMatcher {
  StanzaPathMatcher(super.criteria);

  /// Compare a stanza against a "stanza path". A stanza path is similar to an
  /// XPath expression, but uses the stanza's interfaces and plugins instead of
  /// the underlying XML.
  // @override
  // bool match(XMLBase base) {}
}
