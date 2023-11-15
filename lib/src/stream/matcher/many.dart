import 'package:echox/src/stream/base.dart';
import 'package:echox/src/stream/matcher/base.dart';

/// The [ManyMatcher] matcher may compare a stanza against multiple criteria.
///
/// It is essentially an OR relation combining multiple matchers. Each of the
/// criteria must implement a `match()` method.
class ManyMatcher extends BaseMatcher {
  ManyMatcher(super.criteria);

  /// Match a stanza against multiple criteria. The match is successful if one
  /// of the criteria matches. Each of the criteria must implement a
  /// `match()` method.
  @override
  bool match(XMLBase base) {
    for (final matcher in criteria as Iterable<BaseMatcher>) {
      if (matcher.match(base)) return true;
    }

    return false;
  }
}
