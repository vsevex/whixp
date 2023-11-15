import 'package:echox/src/stream/matcher/base.dart';

/// The StanzaPath matcher selects stanzas that match a given "stanza path",
/// which is similar to a normal `XPath` except that it uses the interfaces and
/// plugins of the stanza instead of the actual, underlying XML.
class StanzaPath extends BaseMatcher {
  StanzaPath(super.criteria);
}
