import 'package:whixp/src/sasl/sasl.dart';
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
  const WhixpInternalException(
    super.message, {
    this.code,
    this.recoverySuggestion,
  });

  /// Optional error code for programmatic error handling.
  final String? code;

  /// Optional recovery suggestion to help users resolve the issue.
  final String? recoverySuggestion;

  /// Whenever there is an exception there in the setup process of the package,
  /// then this exception will be thrown.
  factory WhixpInternalException.setup(
    String message, {
    String? recoverySuggestion,
  }) =>
      WhixpInternalException(
        message,
        code: 'SETUP_ERROR',
        recoverySuggestion: recoverySuggestion,
      );

  /// Factory constructor for [WhixpInternalException] that creates an instance
  /// of the exception with a message "Invalid XML".
  factory WhixpInternalException.invalidXML({String? context}) =>
      WhixpInternalException(
        context != null
            ? 'Invalid XML: $context'
            : 'Invalid XML - unable to parse XML document',
        code: 'INVALID_XML',
        recoverySuggestion:
            'Check that the XML is well-formed and matches expected XMPP format',
      );

  /// Factory constructor for [WhixpInternalException] that creates an instance
  /// of the exception with a message "Invalid node".
  factory WhixpInternalException.invalidNode(String node, String name) =>
      WhixpInternalException(
        'Invalid XML node: found "$node" but expected "$name"',
        code: 'INVALID_NODE',
        recoverySuggestion:
            'Verify the XML structure matches the expected XMPP stanza format',
      );

  /// Factory constructor for [WhixpInternalException] that creates an instance
  /// of the exception with a message "Unexpected XMPP packet".
  factory WhixpInternalException.unexpectedPacket(
    String? namespace,
    String node,
  ) =>
      WhixpInternalException(
        'Unexpected XMPP packet: namespace "$namespace", element "<$node>"',
        code: 'UNEXPECTED_PACKET',
        recoverySuggestion:
            'This may indicate a protocol mismatch or unsupported XEP extension',
      );

  /// Factory constructor for [WhixpInternalException] that creates an instance
  /// of the exception with a message "Unknown namespace while trying to parse
  /// element".
  factory WhixpInternalException.unknownNamespace(String namespace) =>
      WhixpInternalException(
        'Unknown namespace "$namespace" while trying to parse element',
        code: 'UNKNOWN_NAMESPACE',
        recoverySuggestion:
            'The namespace may require a plugin or XEP extension to be enabled',
      );

  /// Factory constructor for [WhixpInternalException] that creates an instance
  /// of the exception with a message "Unable to find stanza for XML Tag".
  factory WhixpInternalException.stanzaNotFound(
    String stanza,
    String tag,
  ) =>
      WhixpInternalException(
        'Unable to find $stanza stanza for XML tag: $tag',
        code: 'STANZA_NOT_FOUND',
        recoverySuggestion:
            'Verify the tag format and ensure the corresponding stanza handler is registered',
      );

  /// Overrides of the `toString` method to return the message of the exception.
  @override
  String toString() {
    final buffer = StringBuffer(message);
    if (code != null) {
      buffer.write(' [Code: $code]');
    }
    if (recoverySuggestion != null) {
      buffer.write('\nSuggestion: $recoverySuggestion');
    }
    return buffer.toString();
  }
}

/// Exception thrown when authentication fails.
class AuthenticationException extends WhixpException {
  /// Creates an [AuthenticationException] with the given [message].
  AuthenticationException(
    super.message, {
    this.code,
    this.recoverySuggestion,
  });

  /// Optional error code for programmatic error handling.
  final String? code;

  /// Optional recovery suggestion to help users resolve the issue.
  final String? recoverySuggestion;

  /// Creates an [AuthenticationException] indicating that TLS is required by the server.
  factory AuthenticationException.requiresTLS() => AuthenticationException(
        'Server requires TLS session but TLS is disabled',
        code: 'TLS_REQUIRED',
        recoverySuggestion:
            'Set disableStartTLS to false or useTLS to true in Transport configuration',
      );

  /// Creates an [AuthenticationException] indicating that TLS is disabled but requested.
  factory AuthenticationException.disabledTLS() => AuthenticationException(
        "TLS session requested but server doesn't support TLS",
        code: 'TLS_NOT_SUPPORTED',
        recoverySuggestion:
            'Disable TLS (set useTLS to false and disableStartTLS to true) or use a server that supports TLS',
      );

  /// Creates an [AuthenticationException] for general authentication failures.
  factory AuthenticationException.failed({
    String? reason,
    String? mechanism,
  }) =>
      AuthenticationException(
        mechanism != null
            ? 'Authentication failed using $mechanism${reason != null ? ": $reason" : ""}'
            : 'Authentication failed${reason != null ? ": $reason" : ""}',
        code: 'AUTH_FAILED',
        recoverySuggestion: mechanism != null
            ? 'Verify credentials are correct for $mechanism mechanism'
            : 'Verify username, password, and that the server supports your authentication method',
      );

  @override
  String toString() {
    final buffer = StringBuffer(message);
    if (code != null) {
      buffer.write(' [Code: $code]');
    }
    if (recoverySuggestion != null) {
      buffer.write('\nSuggestion: $recoverySuggestion');
    }
    return buffer.toString();
  }
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
  factory StanzaException.timeout(Stanza? stanza, {int? timeoutSeconds}) =>
      StanzaException(
        timeoutSeconds != null
            ? 'Waiting for response from server timed out after ${timeoutSeconds}s'
            : 'Waiting for response from the server timed out',
        stanza: stanza,
        condition: 'remote-server-timeout',
      );

  /// Creates a [StanzaException] for a received service unavailable stanza.
  factory StanzaException.serviceUnavailable(Stanza stanza) => StanzaException(
        'Service unavailable: "unknown"',
        stanza: stanza,
        condition: 'service-unavailable',
      );

  /// Creates a [StanzaException] for an IQ error with additional details.
  factory StanzaException.iq(IQ iq) {
    final error = iq.error;
    final errorText = error?.text ?? '';
    final errorReason = error?.reason ?? 'unknown-error';
    final errorType = error?.type ?? 'cancel';
    final stanzaId = iq.id ?? 'unknown';
    final to = iq.to?.toString() ?? 'unknown';

    return StanzaException(
      'IQ error occurred (ID: $stanzaId, To: $to, Type: $errorType, Reason: $errorReason)',
      stanza: iq,
      text: errorText,
      condition: errorReason,
      errorType: errorType,
    );
  }

  /// Creates a [StanzaException] for an IQ timeout.
  factory StanzaException.iqTimeout(IQ iq, {int? timeoutSeconds}) {
    final stanzaId = iq.id ?? 'unknown';
    final to = iq.to?.toString() ?? 'unknown';

    return StanzaException(
      timeoutSeconds != null
          ? 'IQ timeout occurred after ${timeoutSeconds}s (ID: $stanzaId, To: $to)'
          : 'IQ timeout occurred (ID: $stanzaId, To: $to)',
      stanza: iq,
      condition: 'remote-server-timeout',
    );
  }

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
  SASLException(
    super.message, {
    this.extra,
    this.code,
    this.recoverySuggestion,
  });

  /// [extra] is an optional parameter that can be used to pass additional
  /// information about the exception.
  dynamic extra;

  /// Optional error code for programmatic error handling.
  final String? code;

  /// Optional recovery suggestion to help users resolve the issue.
  final String? recoverySuggestion;

  factory SASLException.cancelled(String message) => SASLException(
        message,
        code: 'SASL_CANCELLED',
        recoverySuggestion: 'Authentication was cancelled by user or server',
      );

  factory SASLException.missingCredentials(
    String credential, {
    Mechanism? mech,
  }) =>
      SASLException(
        'Missing credential "$credential" required for ${mech?.name ?? "SASL"} mechanism',
        extra: mech,
        code: 'MISSING_CREDENTIAL',
        recoverySuggestion:
            'Provide the required credential in your SASL callback function',
      );

  factory SASLException.noAppropriateMechanism({
    List<String>? availableMechanisms,
  }) =>
      SASLException(
        availableMechanisms != null && availableMechanisms.isNotEmpty
            ? 'No appropriate SASL mechanism found. Available: ${availableMechanisms.join(", ")}'
            : 'No appropriate SASL mechanism was found',
        code: 'NO_MECHANISM',
        recoverySuggestion:
            'Ensure your SASL callback supports at least one mechanism offered by the server',
      );

  factory SASLException.unimplementedChallenge(String mechanism) =>
      SASLException(
        'Challenge handling is not implemented for mechanism: $mechanism',
        code: 'UNIMPLEMENTED_CHALLENGE',
        recoverySuggestion:
            'This mechanism may require additional implementation or a different mechanism',
      );

  factory SASLException.scram(String message) => SASLException(
        'SCRAM authentication error: $message',
        code: 'SCRAM_ERROR',
        recoverySuggestion:
            'Verify your password and that SCRAM is properly configured',
      );

  factory SASLException.cnonce() => SASLException(
        'Client nonce is not applicable for this SASL mechanism',
        code: 'CNONCE_ERROR',
        recoverySuggestion:
            'This may indicate an internal error in SASL processing',
      );

  factory SASLException.unknownHash(String name) => SASLException(
        'Hash algorithm "$name" is not supported',
        code: 'UNKNOWN_HASH',
        recoverySuggestion:
            'Use a supported hash algorithm (SHA-1, SHA-256, SHA-512)',
      );

  @override
  String toString() {
    final buffer = StringBuffer(message);
    if (code != null) {
      buffer.write(' [Code: $code]');
    }
    if (recoverySuggestion != null) {
      buffer.write('\nSuggestion: $recoverySuggestion');
    }
    return buffer.toString();
  }
}
