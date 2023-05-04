import 'package:echo/src/constants.dart';

import 'package:xml/xml.dart' as xml;

class Utils {
  /// Factory method which returns private instance of this class.
  factory Utils() => _instance;

  /// Private constructor of the class.
  const Utils._();

  /// Constant instance of private constructor.
  static const Utils _instance = Utils._();

  /// Utility method that determines whether `tag` is valid or not.
  ///
  /// Accepts only a parameter which refers to tag, and passes this tag for
  /// further investigation.
  static bool isTagValid(String tag) {
    /// Final variable that equals to `tags` list from constants.
    final tags = xhtml['tags'] as List<String>;

    /// For method for checking all tags according to passed `tag` variable.
    for (int i = 0; i < tags.length; i++) {
      if (tag == tags[i]) {
        return true;
      }
    }
    return false;
  }

  /// Utility method to determine whether an attribute is allowed as recommended
  /// per XEP-0071.
  ///
  /// XHTML attribute names are case sensitive and must be lower case.
  static bool isAttributeValid(String tag, String attribute) {
    /// Final variable that equals to `attributes` list from constants.
    final attributes = xhtml['attributes'] as Map<String, List<String>>;

    /// Check if attribute for the dedicated tag is not null and length
    /// is greater than 0.
    if (attributes[tag] != null && attributes[tag]!.isNotEmpty) {
      for (int i = 0; i < attributes[tag]!.length; i++) {
        if (attribute == attributes[tag]![i]) {
          return true;
        }
      }
    }

    return false;
  }

  /// Utility method to determine whether an css style is allowed as recommended
  /// per XEP-0071.
  static bool isCSSValid(String style) {
    final styles = xhtml['css'] as List<String>;
    for (int i = 0; i < styles.length; i++) {
      if (style == styles[i]) {
        return true;
      }
    }

    return false;
  }

  /// Adds a new namespace to the current namespaces in `ns`.
  /// <br /> @param [String] name - The name under which the namespace will be
  /// referenced under Echo.ns;
  /// <br /> @param [String] value - The actual namespace URI.
  /// <br /> @returns `void`;
  ///
  /// ### Example
  /// ```dart
  /// Echo.addNamespace('PUBSUB', 'http://jabber.org/protocol/pubsub');
  /// ```
  static void addNamespace(String name, String value) {
    ns[name] = value;
  }

  /// Returns a [bool] indicating whether the name of the XML element matches
  /// the specified name.
  /// <br /> The method checks whether the qualified name of the `element`
  /// matches the `name` parameter. If they match, the method returns `true`,
  /// otherwise `false`.
  /// <br /> @param [xml.XmlElement] element - The XML element to compare.
  /// <br /> @param [String] name - The qualified name to compare against the
  /// element's name.
  /// <br /> @return - `true` if the name of the `element` matches the specified
  /// `name`, otherwise `false`.
  static bool isTagEqual(xml.XmlElement element, String name) {
    return element.name.qualified == name;
  }

  /// ### forEachChild
  ///
  /// Map a function over some or all child elements of a given element.
  ///
  /// This is a small convenience function for mapping a function over some or
  /// all of the children of an element. If `element` is `null`, all children
  /// will be passed to the `function`, otherwise only children whose tag names
  /// match `name` will be passed.
  static void forEachChild(
    xml.XmlElement? element,
    String? name,
    void Function(xml.XmlNode) function,
  ) {
    /// Declare non-final `childNode` variable for later assign.
    xml.XmlNode? childNode;

    /// If `element` is null, then exit the function.
    if (element == null) return;

    /// Loop all children in the `element` xml stanzas.
    for (int i = 0; i < element.children.length; i++) {
      if (element.children.elementAt(i) is xml.XmlElement) {
        childNode = element.children.elementAt(i);
      } else if (element.children.elementAt(i) is xml.XmlDocument) {
        childNode = element.root.children.elementAt(i);
      }

      /// If `childNode` is null, then continue to iterate.
      if (childNode == null) continue;

      /// Child element of the given `element`, the function checks whether it
      /// is an `XmlElement` and whether it matches the given `name` filter (if
      /// provided). If both of these conditions are true, the specified
      /// function func is called with the child element as the parameter.
      if (childNode.nodeType == xml.XmlNodeType.ELEMENT &&
          (name == null || isTagEqual(element, name))) {
        function(childNode);
      }
    }
  }
}
