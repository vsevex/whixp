import 'dart:convert';
import 'dart:typed_data';

import 'package:echo/src/constants.dart';

import 'package:xml/xml.dart' as xml;

class Echotils {
  /// Factory method which returns private instance of this class.
  factory Echotils() => _instance;

  /// Private constructor of the class.
  const Echotils._();

  /// Constant instance of private constructor.
  static const Echotils _instance = Echotils._();

  /// These line define field `_xmlGenerator` and a static method
  /// `_makeGenerator()` that returns `_xmlGenerator`. The purpopse of these
  /// lines is to create a single instance of the [XmlBuilder] class that can
  /// be reused throughout the code.
  static final _xmlGenerator = xml.XmlBuilder();

  /// The [XmlBuilder] class is part of the `xml` package in Dart and is used
  /// to generate XML documents. By creating a single instance of `XmlBuilder`
  /// and reusing it, the code can avoid the overhead of creating new
  /// [XmlBuilder] instances for each XML document it generates.
  static xml.XmlBuilder makeGenerator() => _xmlGenerator;

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
      if (style.contains(styles[i])) {
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
  static void addNamespace(String name, String value) => ns[name] = value;

  /// Returns a [bool] indicating whether the name of the XML element matches
  /// the specified name.
  /// <br /> The method checks whether the qualified name of the `element`
  /// matches the `name` parameter. If they match, the method returns `true`,
  /// otherwise `false`.
  ///
  /// <br /> @param [xml.XmlElement] element - The XML element to compare.
  /// <br /> @param [String] name - The qualified name to compare against the
  /// element's name.
  /// <br /> @return - `true` if the name of the `element` matches the specified
  /// `name`, otherwise `false`.
  static bool isTagEqual(xml.XmlElement element, String name) =>
      element.name.qualified == name;

  /// Extracts text content from an XML element.
  ///
  /// This method extracts the text content from an XML element, including any
  /// child.
  /// <br /> @param element - The XML node from which to extract the text.
  /// <br /> @return A [String] containing the text content of the element and
  /// its children.
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

    /// Use `xmlEscape` method to return XML markup.
    return Echotils.xmlEscape(buffer);
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
    void Function(xml.XmlElement) function,
  ) {
    /// If `element` is null, then exit the function.
    if (element == null) return;

    /// Loop all children in the `element` xml stanzas.
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

  /// This is a method colled `copyElement` that takes an `xml.XmlNode` element
  /// as input and returns an `xml.XmlNode` element as output.
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

  /// This is a method that generates an XML element with optional attributes
  /// and nested text.
  ///
  /// The method takes a string argument `name` which represents the name of
  /// the XML element to create. It also takes an optional `attributes`
  /// parameter, which can be either a list of attribute-value pairs or map of
  /// attribute keys and values. The `text` parameter is also optional and
  /// represents the nested text within the element.
  static xml.XmlElement? xmlElement(
    String name, {
    dynamic attributes,
    String? text,
  }) {
    /// Return if the passed `name` is empty.
    if (name.isEmpty || name.trim().isEmpty) {
      return null;
    }

    /// Check if attributes is null or not the type of [List] or [Map].
    if (attributes != null &&
        attributes is! List<List<String>> &&
        attributes is! Map<String, dynamic>) {
      return null;
    }

    /// Define empty attributes for later assign.
    final attrs = <String, String>{};

    /// If the `attributes` argument is a list of lists, the method loops over
    /// each attribute and adds it to a map of attributes.
    if (attributes is List<List<String>>) {
      for (int i = 0; i < attributes.length; i++) {
        final attr = attributes[i];
        if (attr.length == 2 && attr.isNotEmpty) {
          attrs[attr[0]] = attr[1];
        }
      }
    }

    /// the `attributes` argument is a map, the method loops over the keys and
    /// values and adds them to the attribute map.
    else if (attributes is Map<String?, dynamic>) {
      final keys = attributes.keys.toList();
      for (int i = 0; i < keys.length; i++) {
        final key = keys[i];
        if (key != null && key.isNotEmpty && attributes[key] != null) {
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

  /// This method takes an XML DOM element and seralizes it into string
  /// representation of the XML. It uses the `serialize` function to recusively
  /// iterate through all child elements of the input DOM element and construct
  /// a string representation of the XML.
  ///
  /// The resulting string contains all of the attributes and child elements
  /// of the input DOM element, properly escaped as necessary. If the input
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
          '$previous $node="${xmlEscape(element.getAttribute(node.qualified).toString())}"',
    );

    if (element.children.isNotEmpty) {
      result += '>';
      for (final child in element.children) {
        switch (child.nodeType) {
          case xml.XmlNodeType.ELEMENT:

            /// Normal element, so recurse
            result += serialize(child as xml.XmlElement)!;
          case xml.XmlNodeType.TEXT:

            /// Text element to escape values
            result += Echotils.xmlEscape(child.value!);
          case xml.XmlNodeType.CDATA:

            /// cdata section so do not escape values
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

  /// This method creates an XML DOM text node using the provided value.
  ///
  /// It creates an `xml.XmlBuilder` instance using the `makeGenerator()`
  /// method, and then adds an `echo` element with the provided text using the
  /// `element()` method.
  ///
  /// Note that this implementation might not produce the exact same result
  /// as creating a pure text node without the surrounding element, as it adds
  /// an extra `echo` element.
  static xml.XmlNode xmlTextNode(String text) {
    /// Finally, it builds the document using `buildDocument()` and returns the
    /// resulting `xml.XmlNode`.
    return copyElement(xml.XmlText(text));
  }

  /// Returns bare JID from the original JID.
  /// <br /> @param jid - The JID to extract bare from.
  /// <br /> @return The bare JID.
  String? getBareJIDFromJID(String jid) =>
      jid.isNotEmpty ? jid.split("/")[0] : null;

  /// Returns the `username` portion of the given JID, or `null` if the JID
  /// is invalid.
  /// <br /> @param jid - The JID to extract the username from.
  /// <br /> @return The username portion of the JID, or `null` if the JID is
  /// invalid.
  String? getNodeFromJID(String jid) {
    /// Checks whether `jid` parameter contains the "@" character. If it does
    /// not, it returns `null` indicator then.
    if (!jid.contains("@")) return null;

    /// Otherwise, it splits the `jid` string on the "@" character and returns
    /// the first element of the resulting array, which is assumed to be the
    /// username portion of the JID.
    return jid.split("@")[0];
  }

  /// Returns the domain portion of the given JID, or `null` if the JID is
  /// invalid.
  /// <br /> @param jid - The JID to extract the domain from.
  /// <br /> @return The domain portion of the JID, or `null` if the JID is
  /// invalid.
  String? getDomainFromJID(String jid) {
    /// First, extracts the bare JID from the `jid` parameter using the
    /// `getBareJIDFromJID()` function.
    final bare = getBareJIDFromJID(jid);

    /// If the resulting bare JID is not `null` and does not contain the "@"
    /// character, it is assumed to be the domain portion of the JID, and is
    /// returned immediately. If the bare JID contains the "@" character, the
    /// method splits it into two parts and returns the second part, which is
    /// assumed to be domain portion of the JID.
    if (bare != null && !bare.contains("@")) {
      return bare;
    } else {
      final parts = bare!.split("@");
      parts.removeAt(0);
      return parts.join('@');
    }
  }

  /// Returns the resource portion of the given JID, or `null` if the JID is
  /// invalid.
  /// <br /> @param jid - The JID to extract the resource from.
  /// <br /> @return The resource portion of the JID, or `null` if the JID is
  /// invalid.
  String? getResourceFromJID(String jid) {
    /// First, splits the `jid` parameter on the "/" character and checks
    /// whether the resulting array has at least two elements. If it does not,
    /// the method returns `null` to indicate an invalid JID.
    final resource = jid.split("/");
    if (resource.length < 2) return null;

    /// Otherwise, it removes the first element from the array (which is
    /// assumed to be the username or domain portion of the JID) and joins the
    /// remaining elements with "/" characters to form the resource portion of
    /// the JID.
    resource.removeAt(0);
    return resource.join('/');
  }

  /// This is a static method named `escapeNode` that takes a single argument
  /// `node`, a string to be escaped according to the rules of the XMPP nodeprep
  /// profile. The method returns the escaped string.
  ///
  /// The XMPP nodeprep profile specifies that the following characters should
  /// be escaped with a backslash character ("\"):
  ///
  /// * space ("")
  /// * double quote(`"`)
  /// * ampersand (`&`)
  /// * single quote (`'`)
  /// * forward slash (`/`)
  /// * colon (`:`)
  /// * less-than sign (`<`)
  /// * greater-than sign (`>`)
  /// * at sign (`@`)
  ///
  /// Additionally, any leading or trailing whitespace should be removed from
  /// the string.
  static String escapeNode(String node) => node
      .replaceAll(RegExp(r"^\s+|\s+$"), '')
      .replaceAll(RegExp(r"\\"), "\\5c")
      .replaceAll(RegExp(" "), "\\20")
      .replaceAll(RegExp('"'), "\\22")
      .replaceAll(RegExp('&'), "\\26")
      .replaceAll(RegExp("'"), "\\27")
      .replaceAll(RegExp('/'), "\\2f")
      .replaceAll(RegExp(':'), "\\3a")
      .replaceAll(RegExp('<'), "\\3c")
      .replaceAll(RegExp('>'), "\\3e")
      .replaceAll(RegExp('@'), "\\40");

  /// Unescapes a string that has been escaped according to the XMPP protocol
  /// for node identifiers.
  ///
  /// This method replaces certain escape sequences in the `node` parameter with
  /// their corresponding characters. The escape sequences are:
  /// * `\\5c` with "\"
  /// * `\\20` with a space character
  /// * `\\22` with "
  /// * `\\26` with "&"
  /// * `\\27` with "'"
  /// * `\\2f` with "/"
  /// * `\\3a` with ":"
  /// * `\\3c` with "<"
  /// * `\\3e` with ">"
  /// * `\\40` with "@"
  /// <br /> @return The unescaped string.
  static String unescapeNode(String node) => node
      .replaceAll(RegExp(r"\\5c"), "\\")
      .replaceAll(RegExp(r"\\20"), " ")
      .replaceAll(RegExp(r'\\22'), '"')
      .replaceAll(RegExp(r'\\26'), "&")
      .replaceAll(RegExp(r"\\27"), "'")
      .replaceAll(RegExp(r'\\2f'), "/")
      .replaceAll(RegExp(r'\\3a'), ":")
      .replaceAll(RegExp(r'\\3c'), "<")
      .replaceAll(RegExp(r'\\3e'), ">")
      .replaceAll(RegExp(r'\\40'), "@");

  /// This method takes a string parameter `text` and returns a new [String]
  /// with the characters `<`, `>`, `&`, `""`, and `'` replaced with the
  /// corresponding XML entities.
  ///
  /// This method is used to escape special characters in text content that
  /// might be misinterpreted as XML markup. For instance, if a string contains
  /// the character `<`, it needs to be replaced with `&lt;` to prevent it from
  /// being interpreted as the start of a new XML element.
  static String xmlEscape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll("'", '&apos;')
      .replaceAll('"', '&quot;');

  /// This method takes a [String] argument `value` and returns a [String]
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

  /// Takes a base64-encoded string and converts it to an [Uint8List]. It
  /// returns an [List] object that represents the binary data that was
  /// encoded in the base64 string.
  ///
  /// If the input string is not valid base64-encoded string, a [FormatException]
  /// will be thrown. To handle string that are not padded to a multiple of 4
  /// characters, padding characters ('=') are added to the end of the string
  /// as needed.
  ///
  /// The `value` parameter is a base64-encoded string that needs to be
  /// decoded to an [Uint8List].
  ///
  /// ### Example
  /// ```dart
  /// const encoded = 'SGVsbG8gV29ybGQ='
  /// final bytes = Echotils.base64ToArrayBuffer(encoded);
  /// ```
  ///
  /// See also:
  ///
  /// * [base64.encode], which encodes a list of bytes as a base64 string.
  static Uint8List base64ToArrayBuffer(String value) {
    /// Create buffer for further writings.
    final buffer = StringBuffer();

    /// Write the passed `value` inside of it.
    buffer.write(value);

    /// Add equality sign till the length is multiple of a 4.
    while (buffer.length % 4 != 0) {
      buffer.write('=');
    }
    return base64.decode(buffer.toString());
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

  /// Converts a string to a buffer of bytes encoded in UTF-8.
  ///
  /// This method takes a string as input and returns a buffer of bytes encoded
  /// in UTF-8 as a [Uint8List]. This is useful for converting a string to a
  /// format that can be sent over the network or written to a file. To return a
  /// [Uint8List] can be converted back to a string using `utf8.decode`.
  ///
  /// ### Example
  /// ```dart
  /// final value = 'Hello, blya!';
  /// final bytes = Echotils.stringToArrayBuffer(value);
  /// ```
  static Uint8List stringToArrayBuffer(String value) {
    final bytes = value.codeUnits;
    return Uint8List.fromList(bytes);
  }

  /// Performs an XOR operation on two [String]s of the same length and
  /// returns the result as a new [String].
  ///
  /// The [x] and [y] lists must have the same length. The resulting list
  /// contains the XOR of the corresponding elements of [x] and [y].
  ///
  /// Throws an [ArgumentError] if [x] and [y] have different lengths.
  ///
  /// * @param x The first input string to XOR.
  /// * @param y The second input string to XOR.
  /// * @return The result of the XOR operation as a UTF-8 encoded string.
  static String xorUint8Lists(String x, String y) {
    final res = <int>[...x.codeUnits];

    for (var i = 0; i < res.length; i++) {
      res[i] ^= y.codeUnits[i];
    }
    return String.fromCharCodes(res);
  }

  /// Encodes a string using Base64 encoding.
  ///
  /// * @param input The input string to be encoded.
  /// * @return The Base64 encoded string.
  ///
  /// This function encodes a string using Base64 encoding. It takes an input
  /// string as a parameter and returns `Base64` encoded string.
  ///
  /// The `btoa` function internally uses `base64.encode` function to encode
  /// the string. It first converts the input string to an array buffer using
  /// the `stringToArrayBuffer` helper method.
  ///
  /// ### Example usage
  /// ```dart
  /// final encodedString = Echotils.btoa('Hello, World!');
  /// print(encodedString); /// Output: 'SGVsbG8sIFdvcmxkIQ=='
  /// ```
  static String btoa(String input) => base64.encode(stringToArrayBuffer(input));

  /// Decodes a `base64` encoded string.
  ///
  /// This function decodes a `Base64` encoded string. It takes a Base64
  /// encoded string as a parameter and returns the decoded string.
  ///
  /// * @param input The base64 encoded string to be decoded.
  /// * @return The decoded string.
  ///
  /// ### Example usage
  /// ```dart
  /// final decodedString = Echotils.atob('SGVsbG8sIFdvcmxkIQ==');
  /// print(decodedString); /// Output: 'Hello, World!'
  /// ```
  static String atob(String input) =>
      String.fromCharCodes(base64.decode(input));
}
