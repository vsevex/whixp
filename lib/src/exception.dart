/// The given given class is a custom written [Exception] class for [Echo].
///
/// This abstract class provides a way to encapsulate all possible exceptions
/// accross the application.
///
/// ### Usage
/// class SomeException extends EchoException {
///
/// }
abstract class EchoException implements Exception {
  /// Constructs an [EchoException] object with the provided `message` and
  /// `code`.
  const EchoException(this.message, [this.code]);

  /// An optional [int] representing the error code associated with the
  /// exception. If not provided, it defaults to `null`.
  final int? code;

  /// A [String] containing the error message associated with the exception.
  final String message;

  @override
  String toString() =>
      ''' Exception: $message code: ${code ?? 'NOT DECLARED'} ''';
}

/// It is a concrete implementation of the [EchoException] class. It represents
/// an exception specific to WebSocket errors in the [Echo] application.
class WebSocketException extends EchoException {
  /// Constructs a [WebSocketException] object by calling the superclass
  /// constructor [EchoException] with the provided `message` and optional
  /// `code`.
  WebSocketException(super.message, [super.code]);

  /// A factory method that creates a [WebSocketException] object with the
  /// error message set to the given message. This method can be used when
  /// encountering an unknown WebSocket error.
  factory WebSocketException.unknown() =>
      WebSocketException('Unknown WebSocket Error occured.', 11);

  /// Thrown when there is an error with the provided URL.
  factory WebSocketException.invalidURL() =>
      WebSocketException('The given WebSocket URL is invalid.', 400);

  /// [WebSocketException.timedOut] factory method that creates a
  /// [WebSocketException] object with the error message set to the given
  /// message. This method can be used when a WebSocket connection exceeds the
  /// allowed time limit.
  factory WebSocketException.timedOut() =>
      WebSocketException('WebSocket connection timed out.', 22);
}
