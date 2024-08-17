import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/stanza.dart';

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
  const WhixpException(this.message);

  /// A [String] containing the error message associated with the exception.
  final String message;

  @override
  String toString() => '''Whixp Exception: $message''';
}

/// Represents an exception that occurs during the internal processing of Whixp.
class WhixpInternalException extends WhixpException {
  /// Constructor for [WhixpInternalException] that takes a message as a
  /// parameter.
  const WhixpInternalException(super.message);

  /// Whenever there is an exception there in the setup process of the package,
  /// then this exception will be thrown.
  factory WhixpInternalException.setup(String message) =>
      WhixpInternalException(message);

  /// Factory constructor for [WhixpInternalException] that creates an instance
  /// of the exception with a message "Invalid XML".
  factory WhixpInternalException.invalidXML() =>
      const WhixpInternalException('Invalid XML');

  /// Factory constructor for [WhixpInternalException] that creates an instance
  /// of the exception with a message "Invalid node".
  factory WhixpInternalException.invalidNode(String node, String name) =>
      WhixpInternalException('Invalid $node, expecting $name');

  /// Factory constructor for [WhixpInternalException] that creates an instance
  /// of the exception with a message "Unexpected XMPP packet".
  factory WhixpInternalException.unexpectedPacket(
    String? namespace,
    String node,
  ) =>
      WhixpInternalException('Unexpected XMPP packet {$namespace} <$node>');

  /// Factory constructor for [WhixpInternalException] that creates an instance
  /// of the exception with a message "Unknown namespace while trying to parse
  /// element".
  factory WhixpInternalException.unknownNamespace(String namespace) =>
      WhixpInternalException(
        'Unknown namespace($namespace) while trying to parse element',
      );

  /// Factory constructor for [WhixpInternalException] that creates an instance
  /// of the exception with a message "Unable to find stanza for XML Tag".
  factory WhixpInternalException.stanzaNotFound(
    String stanza,
    String tag,
  ) =>
      WhixpInternalException('Unable to find $stanza stanza for XML Tag: $tag');

  /// Overrides of the `toString` method to return the message of the exception.
  @override
  String toString() => message;
}

/// Exception thrown when authentication fails.
class AuthenticationException extends WhixpException {
  /// Creates an [AuthenticationException] with the given [message].
  AuthenticationException(super.message);

  /// Creates an [AuthenticationException] indicating that TLS is required by the server.
  factory AuthenticationException.requiresTLS() => AuthenticationException(
        'Server requires TLS session. Ensure you either "disableStartTLS" attribute to "false"',
      );

  /// Creates an [AuthenticationException] indicating that TLS is disabled but requested.
  factory AuthenticationException.disabledTLS() => AuthenticationException(
        "You requested TLS session, but Server doesn't support TLS",
      );
}

/// Represents an exception related to XMPP stanzas within the context of the
/// [Whixp].
///
/// ### Example:
/// ```dart
/// try {
///   // ...some XMPP-related code that may throw StanzaException
/// } catch (error) {
///   if (error is StanzaException) {
///     print('Stanza Exception: ${error.toString()}');
///   }
/// }
/// ```
class StanzaException extends WhixpException {
  /// Creates a [StanzaException] with the specified error message, stanza, and
  /// optional details.
  StanzaException(
    /// The error message associated with the exception
    super.message, {
    /// The XMPP stanza associated with the exception
    this.stanza,

    /// Additional text information from the stanza related to the exception
    this.text = '',

    /// The condition associated with the exception, defaults to
    /// 'undefined-condition'
    this.condition = 'undefined-condition',

    /// The type of error associated with the exception, defaults to 'cancel'
    this.errorType = 'cancel',
  });

  /// The error message associated with the exception.
  final String text;

  /// The condition associated with the exception.
  final String condition;

  /// The type of error associated with the exception.
  final String errorType;

  /// The XMPP stanza associated with the exception.
  final Stanza? stanza;

  /// Creates a [StanzaException] for a timed-out response from the server.
  factory StanzaException.timeout(Stanza? stanza) => StanzaException(
        'Waiting for response from the server is timed out',
        stanza: stanza,
        condition: 'remote-server-timeout',
      );

  /// Creates a [StanzaException] for a received service unavailable stanza.
  factory StanzaException.serviceUnavailable(Stanza stanza) => StanzaException(
        'Received service unavailable stanza',
        stanza: stanza,
      );

  /// Creates a [StanzaException] for an IQ error with additional details.
  factory StanzaException.iq(IQ iq) => StanzaException(
        'IQ error has occured',
        stanza: iq,
        text: iq.error?.text ?? '',
        condition: iq.error?.reason ?? '',
        errorType: iq.error?.type ?? '',
      );

  /// Creates a [StanzaException] for an IQ timeout.
  factory StanzaException.iqTimeout(IQ iq) => StanzaException(
        'IQ timeout has occured',
        stanza: iq,
        condition: 'remote-server-timeout',
      );

  /// Formats the exception details.
  String get _format {
    final text =
        StringBuffer('$message: Error Type: $errorType, Condition: $condition');

    if (this.text.isNotEmpty) {
      text.write(', Text: ${this.text}');
    }

    return text.toString();
  }

  /// Overrides the [toString] method to provide a formatted string
  /// representation of the exception.
  @override
  String toString() => _format;
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

/// Represents an exception related to SASL (Simple Authentication and Security
/// Layer) mechanisms within the context of the [Whixp].
///
/// ### Example:
/// ```dart
/// try {
///   // ...some SASL-related code that may throw SASLException
/// } catch (error) {
///   if (error is SASLException) {
///     log('SASL Exception: ${e.message}');
///   }
/// }
/// ```
class SASLException extends WhixpException {
  /// Creates a [SASLException] with the specified error message.
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
