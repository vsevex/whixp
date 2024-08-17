import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:whixp/src/escaper/escaper.dart';

import 'package:xml/xml.dart' as xml;

part '_constants.dart';

/// A utility class for various Whixp-related operations.
///
/// Contains a collection of utility methods for performing various operations
/// related to [Whixp], such as XML manipulation, stanza handling, error
/// management, and data conversions.
///
/// ### Example:
/// ```dart
/// final element = WhixpUtils.xmlElement(
///   'book',
///   attributes: {'author': 'Vsevolod', 'year': '2023'},
/// );
///
/// log(element); /// outputs "<book author="Vsevolod" year="2023"/>"
/// ```
class WhixpUtils {
  /// Creates an instance of the [WhixpUtils] utility class.
  ///
  /// Typically, you do not need to create instances of this class, as it
  /// provides static utility methods.
  const WhixpUtils();

  /// Defines field `_xmlGenerator`. The purpose of this code line is to create
  /// a single instance of the [xml.XmlBuilder] class that can be reused
  /// throughout the code.
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
  /// final element = WhixpUtils.xmlElement(
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

  /// Unescapes invalid xml charachters.
  ///
  /// For more information refer to [xmlUnescape] method in [Escaper] class.
  static String xmlUnescape(String text) => Escaper().xmlUnescape(text);

  /// Generates a namespaced element string.
  ///
  /// This method takes an XML element and returns a string in the format
  /// `{namespace}localName`, where `namespace` is the value of the `xmlns`
  /// attribute of the element and `localName` is the local name of the element.
  ///
  /// - [element]: The XML element from which to extract the namespace and
  /// local name.
  ///
  /// Returns a string representing the namespaced element.
  static String generateNamespacedElement(xml.XmlElement element) {
    final namespace = element.getAttribute('xmlns');
    final localName = element.localName;
    return '{$namespace}$localName';
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
  String utf16to8(String value) {
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

  /// Generates a unique ID for use in <iq /> stanzas.
  ///
  /// All <iq /> stanzas are required to have unique id attributes. This
  /// function makes creating this ease. Each connection instance has a counter
  /// which starts from zero, and the value of this counter plus a colon
  /// followed by the `suffix` becomes the unique id. If no suffix is supplied,
  /// the counter is used as the unique id.
  ///
  /// Returns the generated ID.
  static String generateUniqueID([dynamic suffix]) {
    /// It follows the format specified by the UUID version 4 standart.
    final uuid =
        'xxxxx-2113-yxxx-xxxxxxxx'.replaceAllMapped(RegExp('[xy]'), (match) {
      final r = math.Random.secure().nextInt(16);
      final v = match.group(0) == 'x' ? r : (r & 0x3 | 0x8);
      return v.toRadixString(16);
    });

    if (suffix != null) {
      /// Check whether the provided suffix is [String] or [int], so if type is
      /// one of them, proceed to concatting.
      if (suffix is String || suffix is num) {
        return '$uuid:$suffix';
      }
    }

    return uuid;
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
  /// final bytes = WhixpUtils.base64ToArrayBuffer(encoded);
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
  /// final decodedString = WhixpUtils.atob('aGVydCwgbGVya28=');
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
  /// final encodedString = WhixpUtils.btoa('hert, lerko');
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
  /// final bytes = WhixpUtils.stringToArrayBuffer(value);
  /// ```
  static Uint8List stringToArrayBuffer(String value) {
    final bytes = value.codeUnits;
    return Uint8List.fromList(bytes);
  }

  /// Encodes the given [value] using [utf8] encoding. Later on encoded string
  /// can be decoded back using built-in [utf8] decoder.
  static Uint8List utf8Encode(String value) => utf8.encode(value);

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
  /// final streamNamespace = Whixputils.getNamespace('STREAM');
  /// ```
  static String getNamespace(String namespace) =>
      _namespace[namespace.toUpperCase()]!;

  /// Adds a namespace to the current list of namespaces for a server
  /// configuration.
  ///
  /// The [name] of namespace should be a descriptive name for the namespace.
  ///
  /// ### Example:
  /// ```dart
  /// WhixpUtils.addNamespace('CLIENT', 'jabber:client');
  /// ```
  static void addNamespace(String name, String key) => _namespace[name] = key;
}

class Tuple2<F, S> {
  const Tuple2(this.firstValue, this.secondValue);

  final F firstValue;
  final S secondValue;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tuple2 &&
        other.firstValue == firstValue &&
        other.secondValue == secondValue;
  }

  @override
  int get hashCode => firstValue.hashCode ^ secondValue.hashCode;
}

class Tuple3<F, S, T> {
  const Tuple3(this.firstValue, this.secondValue, this.thirdValue);

  final F firstValue;
  final S secondValue;
  final T thirdValue;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Tuple3 &&
        other.firstValue == firstValue &&
        other.secondValue == secondValue &&
        other.thirdValue == thirdValue;
  }

  @override
  int get hashCode =>
      firstValue.hashCode ^ secondValue.hashCode ^ thirdValue.hashCode;
}
