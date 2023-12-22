/// The given given class is a custom written [Exception] class for [Whixp].
///
/// This abstract class provides a way to encapsulate all possible exceptions
/// accross the application.
///
/// ### Example:
/// ```dart
/// class SomeException extends WhixpException {
///   ///...some logic
/// }
/// ```
abstract class WhixpException implements Exception {
  /// Constructs an [WhixpException] object with the provided [message] and
  /// [code].
  const WhixpException(this.message, [this.code]);

  /// An optional [int] representing the error code associated with the
  /// exception. If not provided, it defaults to `null`.
  final int? code;

  /// A [String] containing the error message associated with the exception.
  final String message;

  @override
  String toString() =>
      '''Whixp Exception: $message${code != null ? ' (code: $code)' : ''} ''';
}

class StringPreparationException extends WhixpException {
  StringPreparationException(super.message);

  factory StringPreparationException.unicode(String char) =>
      StringPreparationException(
        'Unicode Error occured - Invalid character: $char',
      );

  factory StringPreparationException.bidiViolation(int step) =>
      StringPreparationException('Violation of BIDI requirement $step');

  factory StringPreparationException.punycode(String message) =>
      StringPreparationException(message);
}

class SASLException extends WhixpException {
  SASLException(super.message);

  factory SASLException.cancelled(String message) => SASLException(message);
  factory SASLException.unknownHash(String name) =>
      SASLException('The $name hashing is not supported');
}
