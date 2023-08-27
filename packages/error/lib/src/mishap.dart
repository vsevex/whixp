import 'package:xml/xml.dart' as xml;

/// Represents an error condition in an XML document.
///
/// Provides methods and properties to extract error information from XML
/// elements and create instance of errors.
class Mishap extends Error {
  /// Constructs a [Mishap] instance with the specified condition and optional
  /// error text and application XML element.
  Mishap({required this.condition, this.text, this.application});

  /// The condition associated with the error.
  final String condition;

  /// The optional error text.
  final String? text;

  /// The optional application XML element.
  final xml.XmlElement? application;

  /// The XML element from which the [Mishap] instance was created.
  ///
  /// It is extracted as a accessible property for further usages.
  late xml.XmlElement element;

  /// Creates a [Mishap] instance from an XML element. It searches for error
  /// elements within the provided XML element and extracts condition, text, and
  /// application information. If no error elements are found, an instance with
  /// an empty condition is returned.
  ///
  /// ### Example:
  /// ```dart
  /// final error = Mishap.fromElement(errorElement);
  ///
  /// log(error.condition); /// outputs error condition
  /// ```
  factory Mishap.fromElement(xml.XmlElement element) {
    /// The method begins by declaring a `List<xml.XmlElement>` variable named
    /// `errors` to store the stream error elements found in the XML document.
    List<xml.XmlElement>? elements;

    /// Searches for stream error elements using the `findElements` method of
    /// the `element` XML document. It looks for elements with the XML namespace
    /// specified by "STREAM" and the namespace "error".
    elements = element.descendantElements.toList();

    /// If no elements are found, it falls back to searching for elements
    /// with the name "error" without a specific namespace.
    if (elements.isEmpty) elements = element.findAllElements('error').toList();

    /// If no stream error elements are found, the method returns `false`,
    /// indicating that no errors were encountered.
    if (elements.isEmpty) return Mishap(condition: '');

    /// Extracts the condition and text values associated with the error.
    String condition = '';
    String? text;
    xml.XmlElement? application;

    /// The method iterates through the child elements of the error element
    /// and checks if their "xmlns" attribute matches the expected namespace
    /// ("urn:ietf:params:xml:ns:xmpp-streams").
    const namespace = "urn:ietf:params:xml:ns:xmpp-streams";
    for (final error in elements) {
      /// If the attribute does not match, the iteration is stopped.
      if (error.getAttribute('xmlns') != namespace) {
        break;
      }

      /// If an element with the local name "text" is found, its inner text is
      /// assigned to the `text` variable.
      if (error.nodeType == xml.XmlNodeType.ELEMENT &&
          error.name.local == 'text') {
        text = error.innerText;
      } else {
        /// Otherwise, the local name of the first child element is assigned to
        /// the `condition` variable.
        condition = error.localName;
      }
    }

    /// If children length is greater or equal to `3`, then equal the part
    /// to the [application].
    if (elements.length >= 3) {
      application = elements.toList()[2];
    }

    final error = Mishap(
      condition: condition,
      text: text,
      application: application,
    );

    error.element = element;

    return error;
  }

  /// Generates a string representation of the [Mishap] instance. It includes
  /// the error condition and, if available, the error text.
  @override
  String toString() => '''$condition (text ${text != null ? '- $text' : ''})''';
}
