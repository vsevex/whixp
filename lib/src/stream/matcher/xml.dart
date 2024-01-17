import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/stream/matcher/base.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// This matcher selects stanzas whose XML matches a certain XML pattern, or
/// mask. For example, the mask may be used to match message stanzas with body
/// elements:
/// ```xml
/// <message xmlns="jabber:client"><body/></message>
/// ```
class XMLMaskMatcher extends BaseMatcher {
  XMLMaskMatcher(super.criteria, {String? defaultNamespace}) {
    _defaultNamespace = defaultNamespace ?? WhixpUtils.getNamespace('CLIENT');
  }

  late final String _defaultNamespace;

  @override
  bool match(XMLBase base) => _maskCompare(
        base.element,
        xml.XmlDocument.parse(criteria as String).rootElement,
      );

  /// Compares an XML object against an XML mask.
  ///
  /// Compares the provided [mask] element with the supplied [source] element.
  /// Whether namespaces should be respected during the comparison.
  bool _maskCompare(
    xml.XmlElement? source,
    xml.XmlElement mask, {
    bool useNamespace = false,
  }) {
    if (source == null) {
      return false;
    }

    final sourceTag = '{${source.getAttribute('xmlns')}}${source.localName}';
    final maskTag =
        '{$_defaultNamespace}{${mask.getAttribute('xmlns')}}${mask.localName}';
    if (!<String>{_defaultNamespace, maskTag}.contains(sourceTag)) {
      return false;
    }

    if (mask.innerText.isNotEmpty &&
        source.innerText.isNotEmpty &&
        source.innerText.trim() != mask.innerText.trim()) {
      return false;
    }

    for (final item in mask.attributes) {
      if (source.getAttribute(item.localName) != item.value) {
        return false;
      }
    }

    final matchedElements = <xml.XmlElement, bool>{};
    for (final subelement in mask.childElements) {
      bool matched = false;
      for (final other in source.findAllElements(
        subelement.localName,
        namespace: subelement.getAttribute('xmlns'),
      )) {
        matchedElements[other] = false;
        if (_maskCompare(
          subelement,
          other,
          useNamespace: useNamespace,
        )) {
          if (matchedElements[other] == null) {
            matchedElements[other] = true;
            matched = true;
          }
        }
      }
      if (!matched) {
        return false;
      }
    }

    return true;
  }
}
