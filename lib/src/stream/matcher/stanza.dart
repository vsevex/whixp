import 'package:dartz/dartz.dart';

import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/stream/matcher/base.dart';
import 'package:whixp/src/utils/utils.dart';

/// Selects stanzas that match a given "stanza path", which is similar to a
/// normal XPath except that it uses the interfaces and plugins of the stanza
/// instead of the actual, underlying XML.
class StanzaPathMatcher extends BaseMatcher {
  /// Compares a stanza against a "stanza path". A stanza path is similar to
  /// XPath expression, but uses the stanza's interfaces and plugins instead
  /// of underlying XML.
  StanzaPathMatcher(super.criteria);

  @override
  bool match(XMLBase base) {
    final rawCriteria = fixNamespace(
      criteria as String,
      split: true,
      propogateNamespace: false,
      defaultNamespace: WhixpUtils.getNamespace('CLIENT'),
    );

    return base.match(rawCriteria) ||
        base.match(Tuple2(criteria as String, null));
  }
}
