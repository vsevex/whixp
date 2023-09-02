import 'dart:typed_data';

import 'package:xml/xml.dart' as xml;

part '_constants.dart';

class Echotils {
  const Echotils();

  /// This line define field `_xmlGenerator`. The purpose of this code line is
  /// to create a single instance of the [xml.XmlBuilder] class that can
  /// be reused throughout the code.
  static final _xmlGenerator = xml.XmlBuilder();

  /// The [xml.XmlBuilder] class is part of the [xml] package in Dart and is
  /// used to generate XML documents.
  ///
  /// By creating a single instance of [xml.XmlBuilder] and reusing it, the code
  /// can avoid the overhead of creating new [xml.XmlBuilder] instances for each
  /// XML document it generates.
  static xml.XmlBuilder makeGenerator() => _xmlGenerator;

  /// Generates an XML element with optional attributes and nested text.
  ///
  /// The method takes a string argument [name] which represents the name of
  /// the XML element to create.
  ///
  /// Also takes an optional [attributes] parameter, which can be either a list
  /// of attribute-value pairs or map of attribute keys and values. The [text]
  /// parameter is also optional and represents the nested text within the
  /// element.
  ///
  /// ### Example:
  /// ```dart
  /// final element = Echotils.xmlElement(
  ///   'test',
  ///   attributes: {'attr1': 'blya'},
  ///   text: 'hert, blya!',
  /// );
  /// log(element); /// outputs "<test attr1="blya">hert, blya!</test>"
  /// ```
  static xml.XmlElement xmlElement(
    String name, {
    dynamic attributes,
    String? text,
  }) {
    /// Return if the passed `name` is empty.
    if (name.isEmpty || name.trim().isEmpty) {
      throw UnimplementedError('Name can not not be empty');
    }

    /// Check if attributes is null or not the type of [List] or [Map].
    if (attributes != null &&
        attributes is! List<Map<String, String>> &&
        attributes is! Map<String, String>) {
      throw ArgumentError('Attributes must be a List of Map or a Map');
    }

    /// Define empty attributes for later assign.
    final attrs = <String, String>{};

    /// If the `attributes` argument is a list of maps, the method loops over
    /// each attribute and adds it to a map of attributes.
    if (attributes is List<Map<String, String>>) {
      for (int i = 0; i < attributes.length; i++) {
        final attr = attributes[i];
        if (attr.isNotEmpty) {
          for (final entry in attr.entries) {
            attrs[entry.key] = entry.value;
          }
        }
      }
    }

    /// the `attributes` argument is a map, the method loops over the keys and
    /// values and adds them to the attribute map.
    if (attributes is Map<String, String>) {
      final keys = attributes.keys.toList();
      for (int i = 0; i < keys.length; i++) {
        final key = keys[i];
        if (key.isNotEmpty && attributes[key] != null) {
          attrs[key] = attributes[key].toString();
        }
      }
    }

    /// The method then creates an instance of `xml.XmlBuilder` and uses it to
    /// generate the XML element with the provided one, attributes, and nested
    /// text.
    ///
    /// Finally, it returns the resulting XML node. If the `name` argument is
    /// empty or contains only whitespace, or if the `attributes` argument is
    /// not a valid type, the method returns `null`.
    final builder = makeGenerator();
    builder.element(name, attributes: attrs, nest: text);
    return builder.buildDocument().rootElement.copy();
  }

  /// This method creates an XML text node using the provided [text].
  ///
  /// Creates an [xml.XmlBuilder] instance using the `makeGenerator()` method.
  ///
  /// ### Example:
  /// ```dart
  /// final textNode = Echotils.xmlTextNode('hert');
  ///
  /// log(textNode.root.value); /// outputs "hert"
  /// ```
  static xml.XmlNode xmlTextNode(String text) => copyElement(xml.XmlText(text));

  /// This is a method colled [copyElement] that takes an [xml.XmlNode] element
  /// as input and returns an [xml.XmlNode] element as output.
  ///
  /// Overall this method provides a way to make a deep copy of an XML node and
  /// all its descendants.
  static xml.XmlNode copyElement(xml.XmlNode element) {
    /// The method checks whether the node is an element or a text node.
    ///
    /// If the node is an element, it creates a new element with the same tag
    /// name and copies all attributes and child nodes of the original element.
    if (element is xml.XmlElement &&
        element.nodeType == xml.XmlNodeType.ELEMENT) {
      final elem = element.copy();

      for (int i = 0; i < element.attributes.length; i++) {
        elem.setAttribute(
          element.attributes[i].name.qualified,
          element.attributes[i].value,
        );
      }

      for (int i = 0; i < element.nodes.length; i++) {
        element.children.map((node) => elem.children.add(node));
      }

      return elem;
    }

    /// If the node is a text node, it creates a new text node with the same
    /// text content as the original node.
    else if (element.nodeType == xml.XmlNodeType.TEXT) {
      return xml.XmlText(element.value!);
    }

    /// The method throws an [ArgumentError] if the input node is of an
    /// unsupported type.
    throw ArgumentError('Invalid node type: ${element.nodeType}');
  }

  /// Returns a [bool] indicating whether the name of the XML element matches
  /// the specified name.
  /// <br /> Checks whether the qualified name of the [element] matches the
  /// [name] parameter. If they match, the method returns `true`, otherwise
  /// `false`.
  ///
  /// ### Example:
  /// ```dart
  /// final isEqual = Echotils.isTagEqual(childElement, 'hert');
  /// ```
  static bool isTagEqual(xml.XmlElement element, String name) =>
      element.name.qualified == name;

  /// Maps a function over some or all child elements of a given element.
  ///
  /// This is a small convenience function for mapping a function over some or
  /// all of the children of an element. If [element] is `null`, all children
  /// will be passed to the [function], otherwise only children whose tag names
  /// match [name] will be passed.
  static void forEachChild(
    xml.XmlElement? element,
    String? name,
    void Function(xml.XmlElement child) function,
  ) {
    /// If [element] is null, then exit the function.
    if (element == null) return;

    /// Loop all children in the [element] xml stanzas.
    for (int i = 0; i < element.descendantElements.length; i++) {
      /// Declare final `childNode` variable for the `i` element.
      final childNode = element.descendantElements.toList()[i];

      /// Child element of the given `element`, the function checks whether it
      /// is an `XmlElement` and whether it matches the given `name` filter (if
      /// provided). If both of these conditions are true, the specified
      /// function func is called with the child element as the parameter.
      if (childNode.nodeType == xml.XmlNodeType.ELEMENT &&
          (name == null || isTagEqual(childNode, name))) {
        function(childNode);
      }
    }
  }

  /// Converts a string to a buffer of bytes encoded in UTF-8.
  ///
  /// Takes a string as input and returns a buffer of bytes encoded in UTF-8 as
  /// a [Uint8List]. This is useful for converting a string to a format that can
  /// be sent over the network or written to a file. To return a [Uint8List] can
  /// be converted back to a string using `utf8.decode`.
  ///
  /// ### Example:
  /// ```dart
  /// final value = 'hert, blya!';
  /// final bytes = Echotils.stringToArrayBuffer(value);
  /// ```
  static Uint8List stringToArrayBuffer(String value) {
    final bytes = value.codeUnits;
    return Uint8List.fromList(bytes);
  }

  /// Retrieves namespace [String] from namespace [Map] according to the passed
  /// retriever.
  ///
  /// ### Example:
  /// ```dart
  /// final streamNamespace = Echotils.getNamespace('STREAM');
  /// ```
  static String getNamespace(String ns) => namespace[ns]!;
}
