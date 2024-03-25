import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/stream/matcher/base.dart';

/// A matcher class for comparing stanzas against a "stanza path".
///
/// The [XPathMatcher] class extends [BaseMatcher] and provides an
/// implementation for comparing a stanza against a stanza path. The stanza path
/// is similar to an XPath expression but uses the stanza's interfaces and
/// plugins instead of the underlying XML.
class XPathMatcher extends BaseMatcher {
  /// Constructs an [XPathMatcher] with the specified criteria.
  ///
  /// The [criteria] parameter represents the stanza path against which stanzas
  /// will be compared.
  XPathMatcher(super.criteria);

  /// Compare a stanza against a "stanza path". A stanza path is similar to an
  /// XPath expression, but uses the stanza's interfaces and plugins instead of
  /// the underlying XML.
  ///
  /// ### Example:
  /// ```dart
  /// final matcher = XPathMatcher('{namespace}name');
  /// ```
  ///
  /// __Note__: Actually, this class is not matches stanzas over the XPath expression.
  /// It is just placeholder for the actual name, instead XPath, it uses custom
  /// element tag for comperison.
  @override
  bool match(XMLBase base) {
    final element = base.element;

    /// Namespace fix.
    final rawCriteria = fixNamespace(criteria as String, split: true).value2;

    /// Retrieves the XML tag of the [base.element].
    final tag =
        '<${element!.localName} xmlns="${element.getAttribute('xmlns') ?? ''}"/>';

    /// Compare the stored criteria with the XML tag of the stanza.
    return rawCriteria?.contains(tag) ?? false;
  }
}
