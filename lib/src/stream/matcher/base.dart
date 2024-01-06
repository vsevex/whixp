import 'package:whixp/src/stream/base.dart';

/// Base class for stanza matchers.
///
/// Stanza matchers are used to pick stanzas out of the XML stream and pass
/// them to the appropriate stream handlers.
abstract class BaseMatcher {
  BaseMatcher(this.criteria);

  final dynamic criteria;

  /// Checks if a stanza matches the stored criteria.
  bool match(XMLBase base) => false;
}
