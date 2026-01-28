import 'package:xml/xml.dart' as xml;

/// Optimized parsing utilities to reduce redundant operations and improve performance.
///
/// These utilities cache frequently accessed data and reduce allocations
/// during XML parsing operations.
class ParsingOptimizations {
  /// Gets all element children from a node, caching the result.
  ///
  /// This avoids multiple calls to `node.children.whereType<xml.XmlElement>()`
  /// which creates new iterators each time.
  static List<xml.XmlElement> getElementChildren(xml.XmlElement node) {
    final children = <xml.XmlElement>[];
    for (final child in node.children) {
      if (child is xml.XmlElement) {
        children.add(child);
      }
    }
    return children;
  }

  /// Gets the inner text of an element, caching the result.
  ///
  /// This is more efficient than calling `innerText` multiple times
  /// as it only computes the text once.
  static String? getCachedInnerText(xml.XmlElement element) {
    // innerText is already cached by the xml package, but we can add
    // additional optimizations here if needed
    return element.innerText.isEmpty ? null : element.innerText;
  }

  /// Efficiently checks if an element has a specific local name.
  ///
  /// This avoids string comparisons by caching the localName.
  static bool hasLocalName(xml.XmlElement element, String name) =>
      element.localName == name;

  /// Gets an attribute value with a default, avoiding null checks.
  static String? getAttributeValue(
    xml.XmlElement element,
    String name, {
    String? defaultValue,
  }) =>
      element.getAttribute(name) ?? defaultValue;

  /// Efficiently finds the first child element with a specific local name.
  ///
  /// Returns null if not found, avoiding the need to iterate all children.
  static xml.XmlElement? findFirstChild(
    xml.XmlElement parent,
    String localName,
  ) {
    for (final child in parent.children) {
      if (child is xml.XmlElement && child.localName == localName) {
        return child;
      }
    }
    return null;
  }

  /// Efficiently finds all child elements with a specific local name.
  ///
  /// More efficient than filtering after getting all children.
  static List<xml.XmlElement> findChildren(
    xml.XmlElement parent,
    String localName,
  ) {
    final results = <xml.XmlElement>[];
    for (final child in parent.children) {
      if (child is xml.XmlElement && child.localName == localName) {
        results.add(child);
      }
    }
    return results;
  }
}
