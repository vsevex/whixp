import 'package:echox/src/stream/base.dart';

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

class StanzaException extends WhixpException {
  StanzaException(
    super.message,
    this.stanza, {
    this.text = '',
    this.condition = 'undefined-condition',
    this.errorType = 'cancel',
  });

  final String text;
  final String condition;
  final String errorType;
  final XMLBase stanza;

  factory StanzaException.timeout(StanzaBase stanza) => StanzaException(
        'Waiting for response from the server is timed out',
        stanza,
        condition: 'remote-server-timeout',
      );
  factory StanzaException.iq(XMLBase stanza) {
    return StanzaException(
      'IQ error is occured',
      stanza,
      text: stanza['text'] as String,
      condition: stanza['condition'] as String,
      errorType: stanza['type'] as String,
    );
  }
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
  factory SASLException.missingCredentials(String credential) =>
      SASLException('Missing credential in SASL mechanism: $credential');
  factory SASLException.noAppropriateMechanism() =>
      SASLException('No appropriate mechanism was found');
  factory SASLException.unimplementedChallenge(String mechanism) =>
      SASLException('Challenge is not implemented for: $mechanism');
  factory SASLException.scram(String message) => SASLException(message);
  factory SASLException.cnonce() =>
      SASLException('Client nonce is not applicable');
  factory SASLException.unknownHash(String name) =>
      SASLException('The $name hashing is not supported');
}
