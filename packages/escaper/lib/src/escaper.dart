/// Provides methods for escaping charachters in strings.
///
/// ### Example:
/// ```dart
/// final text = 'hert "blya"';
///
/// final escapedText = Escaper().xmlEscape(text);
/// log(escapedText); /// Must print out 'hert &quot;blya&quot;'
/// ```
class Escaper {
  /// This constructor is used to create a new [Escaper] instance.
  factory Escaper() => _instance;

  const Escaper._();

  /// The static variable is a singleton instance of the [Escaper] class.
  ///
  /// This variable will be used to get a reference to the [Escaper] class
  /// without having to create a new instance.
  static const Escaper _instance = Escaper._();

  /// Takes a [text] string and returns a new [String] with the characters `<`,
  /// `>`, `&`, `""`, and `'` replaced with the corresponding XML entities.
  ///
  /// The usage purpose of this method is to escape special characters in text
  /// content that might be misinterpreted as XML markup. For instance, if a
  /// [String] contains the character `<`, it needs to be replaced with `&lt;`
  /// to prevent it from being interpreted as the start of a new XML element.
  ///
  /// ### Example:
  /// ```dart
  /// final text = 'hert "blya"';
  ///
  /// final escapedText = Escaper().xmlEscape(text);
  /// log(escapedText); /// outputs 'hert &quot;blya&quot;'
  /// ```
  String xmlEscape(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll("'", '&apos;')
      .replaceAll('"', '&quot;');

  /// Escapes characters in the given text that are not allowed in JIDs
  /// according to the rules of the XMPP nodeprep profile. Returns the escaped
  /// string.
  ///
  /// The XMPP nodeprep profile specifies that the following characters should
  /// be escaped with a backslash character ("\"):
  ///
  /// * space (`" "`)
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
  ///
  /// ### Example:
  /// ```dart
  /// final text = 'hert blya';
  ///
  /// final escapedText = Escaper().escape(text);
  /// log(escapedText); /// outputs 'hert\\20blya'
  /// ```
  String escape(String node) => node
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
  /// This method replaces certain escape sequences in the [node] parameter with
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
  ///
  /// Returns the unescaped [String].
  ///
  /// ### Example:
  /// ```dart
  /// final text = 'hert\\20blat';
  ///
  /// final escapedText = Escaper().escape(text);
  /// log(escapedText); /// outputs 'hert blat'
  /// ```
  String unescape(String node) => node
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
}
