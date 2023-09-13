part of 'jid.dart';

/// Detects the presence of specific characters in a given string.
///
/// Takes [local] string as input and checks for the presence of characters that
/// match the regular expression pattern. If no matches are found, the method
/// returns `false`, indicating that the input string does not contain any of
/// the specified characters.
///
/// ### Example:
/// ```dart
/// final result = _detect('hert@blya');
/// log(result); // outputs `true`.
/// ```
bool _detect(String local) {
  final matcher = RegExp(r'[ "&\/:<>@\\]');
  final escaped = Escaper().escape(local);

  if (!matcher.hasMatch(escaped)) {
    return false;
  }

  return true;
}
