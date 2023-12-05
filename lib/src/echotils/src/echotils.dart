import 'dart:convert';
import 'dart:mirrors' as mirrors;
import 'dart:typed_data';

import 'package:echox/src/echotils/src/status.dart';
import 'package:echox/src/escaper/escaper.dart';

import 'package:xml/xml.dart' as xml;

part '_constants.dart';

/// A utility class for various EchoX-related operations.
///
/// Contains a collection of utility methods for performing various operations
/// related to [EchoX], such as XML manipulation, stanza handling, error
/// management, and data conversions.
///
/// ### Example:
/// ```dart
/// final element = Echotils.xmlElement(
///   'book',
///   attributes: {'author': 'Vsevolod', 'year': '2023'},
/// );
///
/// log(element); /// outputs "<book author="Vsevolod" year="2023"/>"
/// ```
class Echotils {
  /// Creates an instance of the [Echotils] utility class.
  ///
  /// Typically, you do not need to create instances of this class, as it
  /// provides static utility methods.
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
  static xml.XmlBuilder _makeGenerator() => _xmlGenerator;

  /// Generates an XML element with optional attributes and nested text.
  ///
  /// Takes a string argument [name] which represents the name of the XML
  /// element to create.
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
    dynamic attributes /** List<Map<String, String>> || Map<String, String> */,
    String? namespace,
    String? text,
  }) {
    /// Return if the passed `name` is empty.
    if (name.isEmpty || name.trim().isEmpty) {
      throw UnimplementedError('Name can not not be empty');
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
    final builder = _makeGenerator();
    builder.element(
      name,
      nest: () {
        if (namespace != null) {
          builder.namespace(namespace);
        }
        for (final entry in attrs.entries) {
          builder.attribute(entry.key, entry.value, namespace: namespace);
        }
        if (text != null) {
          builder.text(text);
        }
      },
      namespace: namespace,
    );
    return builder.buildDocument().rootElement.copy();
  }

  /// Extracts and concatenates the text content from an XML element and its
  /// descendants.
  ///
  /// This method traverses the XML element's children recursively and collects
  /// all text content within the element and its descendants. It returns the
  /// concatenated text content as a single string with XML escaping applied.
  ///
  /// If the provided [element] is an XML text node, its value is directly
  /// included in the result string. If it is an XML element node, this method
  /// recursively traverses its children to gather text content.
  ///
  /// ### Example:
  /// ```dart
  /// final element =
  ///     xml.XmlDocument.parse('<root>hert lerko</root>').rootElement;
  /// final result = Echotils.getText(element); /// outputs "hert lerko"
  /// ```
  static String getText(xml.XmlNode element) {
    /// Define empty string buffer without [StringBuffer].
    String buffer = '';

    if (element.children.isEmpty && element.nodeType == xml.XmlNodeType.TEXT) {
      buffer += element.value!;
    }

    for (int i = 0; i < element.children.length; i++) {
      if (element.children[i].nodeType == xml.XmlNodeType.TEXT) {
        buffer += element.children[i].value!;
      } else if (element.children[i].nodeType == xml.XmlNodeType.ELEMENT) {
        /// Recursively run the method for gathering if there is a text inside
        /// of the passed element.
        buffer += getText(element.children[i]);
      }
    }

    return Escaper().xmlEscape(buffer);
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

  /// This is a method colled [copyElement] that takes an [xml.XmlNode]
  /// [element] as input and returns an [xml.XmlNode] element as output.
  ///
  /// In overall, this method provides a way to make a deep copy of an XML node
  /// and all its descendants.
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
    if (element == null) return;

    for (int i = 0; i < element.descendantElements.length; i++) {
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

  /// This method takes an XML [element] and seralizes it into string
  /// representation of the XML. It uses the `serialize` function to recusively
  /// iterate through all child elements of the input [element] and construct
  /// a string representation of the XML.
  ///
  /// The resulting string contains all of the attributes and child elements
  /// of the input element, properly escaped as necessary. If the input
  /// element has no children, then the output will be a self-closing tag.
  static String? serialize(xml.XmlElement? element) {
    /// If element is null, then return null.
    if (element == null) return null;
    final names = List.generate(
      element.attributes.length,
      (i) => element.attributes[i].name,
    );
    names.sort((a, b) => a.qualified.compareTo(b.qualified));
    String result = names.fold(
      '<${element.name.qualified}',
      (previous, node) =>
          '$previous $node="${Escaper().xmlEscape(element.getAttribute(node.qualified).toString())}"',
    );

    if (element.children.isNotEmpty) {
      result += '>';

      for (final child in element.children) {
        switch (child.nodeType) {
          case xml.XmlNodeType.ELEMENT:
            result += serialize(child as xml.XmlElement)!;
          case xml.XmlNodeType.TEXT:
            result += Escaper().xmlEscape(child.value!);
          case xml.XmlNodeType.CDATA:
            result += '<![CDATA[${child.value}]]>';
          default:
            break;
        }
      }
      result += '</${element.name.qualified}>';
    } else {
      result += '/>';
    }
    return result;
  }

  /// This method takes a [String] argument [value] and returns a [String]
  /// in UTF-8. It works by iterating through each character in the input string
  /// and converting each character to its UTF-8 equivalent.
  static String utf16to8(String value) {
    String out = '';
    final length = value.length;

    /// The method first initializes `out` that will hold the UTF-8 encoded string.
    /// It then loops through each character in the input string using a for loop.
    for (int i = 0; i < length; i++) {
      final c = value.codeUnitAt(i);

      /// It retrieves the Unicode code point of the current character using
      /// the `charCodeAt` method and stores it in the variable `c`. It then
      /// checks if the code point is in the range of ASCII characters
      /// (0x0000 to 0x007f). If so, simply appends the character to the `out`
      /// string.
      if (c >= 0x0000 && c < 0x007f) {
        out += value[i];
      } else if (c > 0x07ff) {
        /// If the code point is outside the ASCII range, the method checks if
        /// it is greater than 0x007f, which indicates that the character is in
        /// the range of two-byte characters. In this case, it calculates the
        /// two bytes that represents the character using bit shifting and
        /// bitwise OR operations, and appends them to the `out` string.
        out += String.fromCharCode(0xe0 | ((c >> 12) & 0x0f));
        out += String.fromCharCode(0x80 | ((c >> 6) & 0x3f));
        out += String.fromCharCode(0x80 | ((c >> 0) & 0x3f));
      } else {
        /// If the code point is not in the two-byte range, it is in the range
        /// of three-byte characters. In this case, the method calculates the
        /// three bytes that represent the character using bit shifting and
        /// bitwise OR operations, and appends them to the out string.
        out += String.fromCharCode(0xc0 | ((c >> 6) & 0x1f));
        out += String.fromCharCode(0x80 | ((c >> 0) & 0x3f));
      }
    }
    return out;
  }

  /// Performs an XOR operation on two [String]s of the same length and
  /// returns the result as a new [String].
  ///
  /// The [x] and [y] lists must have the same length. The resulting list
  /// contains the XOR of the corresponding elements of [x] and [y].
  static String xorUint8Lists(String x, String y) {
    final res = <int>[...x.codeUnits];

    for (var i = 0; i < res.length; i++) {
      res[i] ^= y.codeUnits[i];
    }
    return String.fromCharCodes(res);
  }

  /// Takes a base64-encoded string and converts it to an [Uint8List]. It
  /// returns an [List] object that represents the binary data that was
  /// encoded in the base64 string.
  ///
  /// To handle string that are not padded to a multiple of 4 characters,
  /// padding characters ('=') are added to the end of the string as needed.
  ///
  /// The [value] parameter is a base64-encoded string that needs to be
  /// decoded to an [Uint8List].
  ///
  /// ### Example:
  /// ```dart
  /// const encoded = 'SGVsbG8gV29ybGQ='
  /// final bytes = Echotils.base64ToArrayBuffer(encoded);
  /// ```
  ///
  /// See also:
  ///
  /// * [base64.encode], which encodes a list of bytes as a base64 string.
  static Uint8List base64ToArrayBuffer(String value) {
    final buffer = StringBuffer();

    buffer.write(value);

    while (buffer.length % 4 != 0) {
      buffer.write('=');
    }
    return base64.decode(buffer.toString());
  }

  /// Decodes a `base64` encoded string.
  ///
  /// This function decodes a `Base64` encoded string. It takes a Base64
  /// encoded string as a parameter and returns the decoded string.
  ///
  /// ### Example:
  /// ```dart
  /// final decodedString = Echotils.atob('aGVydCwgbGVya28=');
  /// print(decodedString); /// outputs "hert, lerko"
  /// ```
  static String atob(String input) =>
      String.fromCharCodes(base64.decode(input));

  /// Encodes a string using Base64 encoding based on the passed `input` string.
  ///
  /// This function encodes a string using Base64 encoding. It takes an input
  /// string as a parameter and returns `Base64` encoded string.
  ///
  /// The `btoa` function internally uses `base64.encode` function to encode
  /// the string. It first converts the input string to an array buffer using
  /// the `stringToArrayBuffer` helper method.
  ///
  /// ### Example
  /// ```dart
  /// final encodedString = Echotils.btoa('hert, lerko');
  /// print(encodedString); /// outputs "aGVydCwgbGVya28='"
  /// ```
  static String btoa(String input) => base64.encode(stringToArrayBuffer(input));

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

  /// This method takes a [Uint8List] as input, representing an array of bytes,
  /// and converts it to a Base64-encoded string. The method first converts
  /// the [ByteBuffer] to a [Uint8List] using the `asUint8List` method.
  static String arrayBufferToBase64(Uint8List buffer) {
    final binary = StringBuffer();

    /// Iterates over each byte in the list and converts it to a character using
    /// the `String.fromCharCode` method.
    for (int i = 0; i < buffer.lengthInBytes; i++) {
      /// The resulting characters are concatenated together into a binary
      /// string using a [StringBuffer].
      binary.write(String.fromCharCode(buffer[i]));
    }

    /// The binary string is encoded into a Base64-encoded string using the
    /// `base64.encode` method. The resulted Base64-encoded string is returned.
    return base64.encode(buffer);
  }

  /// Converts a byte sequence or string to Unicode string.
  ///
  /// If the input [text] is a byte sequence (bytes), it is decoded using the
  /// UTF-8 encoding. If the input is already a string, it is returned as is.
  static String unicode(dynamic data /** List<int> || String */) {
    if (data is! String) {
      return utf8.decode(data as List<int>);
    }

    return data;
  }

  /// Retrieves namespace [String] from namespace [Map] according to the passed
  /// retriever.
  ///
  /// ### Example:
  /// ```dart
  /// final streamNamespace = Echotils.getNamespace('STREAM');
  /// ```
  static String getNamespace(String ns) => _namespace[ns.toUpperCase()]!;

  /// Adds a namespace to the current list of namespaces for a server
  /// configuration.
  ///
  /// The [name] of namespace should be a descriptive name for the namespace.
  ///
  /// ### Example:
  /// ```dart
  /// Echotils.addNamespace('CLIENT', 'jabber:client');
  /// ```
  static void addNamespace(String name, String key) => _namespace[name] = key;

  /// Checks if an object has a specified property using reflection.
  ///
  /// Uses Dart's reflection capabilities to inspect the structure of an
  /// [object] at runtime and determine whether it has a property with the given
  /// [property].
  ///
  /// ### Example:
  /// ```dart
  /// final object = SomeClass();
  /// if (Echotils.hasAttr(object, 'property')) {
  ///   log('property exists!');
  /// } else {
  ///   /// ...otherwise do something
  /// }
  /// ```
  /// **Warning:**
  /// * Reflection can be affected by certain build configurations, and the
  /// effectiveness of this function may vary in those cases.
  static bool hasAttr(Object? object, String property) {
    final instanceMirror = mirrors.reflect(object);
    return instanceMirror.type.instanceMembers.containsKey(Symbol(property));
  }

  /// Gets the value of an attribute from an object using reflection.
  ///
  /// This function uses Dart's reflection capabilities to inspect the structure
  /// of an object at runtime and retrieves the value of an attribute with the
  /// specified name.
  ///
  /// ### Example:
  /// ```dart
  /// final exampleObject = Example();
  /// final name = Echotils.getAttr(exampleObject, 'name');
  /// log(name); /// outputs name
  /// ```
  ///
  /// **Warning:**
  /// * Reflection can be affected by certain build configurations, and the
  /// effectiveness of this function may vary in those cases.
  static dynamic getAttr(Object? object, String attribute) {
    final instanceMirror = mirrors.reflect(object);

    try {
      final value = instanceMirror.getField(Symbol(attribute)).reflectee;
      return value;
    } catch (error) {
      return null;
    }
  }

  /// Sets the value of an attribute on an object using reflection.
  ///
  /// Uses Dart's reflection capabilities to inspect the structure of an object
  /// at runtime and sets the value of an attribute with the specified name.
  ///
  /// ### Example:
  /// ```dart
  /// final exampleObject = Example();
  /// final name = Echotils.setAttr(exampleObject, 'name', 'hert');
  /// ```
  /// **Warning:**
  /// * Reflection can be affected by certain build configurations, and the
  /// effectiveness of this function may vary in those cases.
  static void setAttr(Object? object, String attribute, dynamic value) {
    if (value is Function) {
      throw ArgumentError("Setting methods dynamically is not supported.");
    }
    final instanceMirror = mirrors.reflect(object);
    try {
      instanceMirror.setField(Symbol(attribute), value);
    } catch (error) {
      /// Handle cases where the attribute does not exist
      throw ArgumentError("Attribute '$attribute' not found");
    }
  }
}

/// Helps to emit status information.
///
/// The [StatusEmitter] class is used to represent and emit status updates. It
/// contains information about the status itself and an optional description
/// providing additional context and information.
///
/// Status updates are emitted using the [EventEmitter] class, which is often
/// extended by the main class where status updates are relevant.
///
/// ### Example:
/// ```dart
/// final status = StatusEmitter(EchoStatus.connected, 'EchoX client connected.');
/// log(status); /// outputs "Status: Connected (description: Client connected.)";
/// ```
class StatusEmitter {
  /// Creates a [StatusEmitter] instance with the given [status] and optional
  /// [description].
  ///
  /// The [status] parameter represents the status of the emitter, and
  /// [description] can provide additional information about the status.
  const StatusEmitter(this.status, [this.description]);

  /// The status information.
  final EchoStatus status;
  final String? description;

  @override
  String toString() =>
      '''Status: $status${description != null ? ' (description: $description)' : ''}''';
}
