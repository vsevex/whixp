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

  /// Embedded `copyWith` method in the abstraction of [EchoException].
  EchoException copyWith({String? message, int? code});

  @override
  String toString() =>
      '''Exception: $message${code != null ? ' (code: $code)' : ''} ''';
}

/// [EchoExceptionMapper] is a custom exception class that extends [EchoException].
/// It provides a set of factory methods for creating different types of
/// exceptions commonly encountered in an application, along with their
/// corresponding HTTP status codes.
///
/// Example usage:
/// ```dart
/// throw EchoExceptionMapper.notFound();
/// ```
class EchoExceptionMapper extends EchoException {
  /// Constructs an [EchoExceptionMapper] with the given [message] and an optional
  /// [code].
  EchoExceptionMapper(super.message, [super.code]);

  /// Creates an [EchoExceptionMapper] representing a `Bad Request` exception
  /// (HTTP 400).
  factory EchoExceptionMapper.badRequest() =>
      EchoExceptionMapper('Bad Request has been made', 400);

  /// Creates an [EchoExceptionMapper] representing a `Not Authorized` exception
  /// (HTTP 401).
  factory EchoExceptionMapper.notAuthorized() =>
      EchoExceptionMapper('You are not authorized to do this action', 401);

  /// Creates an [EchoExceptionMapper] representing a `Forbidden` exception
  /// (HTTP 403).
  factory EchoExceptionMapper.forbidden() =>
      EchoExceptionMapper('Forbidden', 403);

  /// Creates an [EchoExceptionMapper] representing a `Not Found` exception
  /// (HTTP 404).
  factory EchoExceptionMapper.notFound() =>
      EchoExceptionMapper('Nothing found for your request', 404);

  /// Creates an [EchoExceptionMapper] representing a `Not Allowed` exception
  /// (HTTP 405).
  factory EchoExceptionMapper.notAllowed() =>
      EchoExceptionMapper('You are not allowed to do this action', 405);

  /// Creates an [EchoExceptionMapper] representing a `Registration Required`
  /// exception (HTTP 407).
  factory EchoExceptionMapper.registrationRequired() => EchoExceptionMapper(
        'You need to register in order to make this request',
        407,
      );

  /// Creates an [EchoExceptionMapper] representing a `Request Timed Out` exception
  /// (HTTP 408).
  factory EchoExceptionMapper.requestTimedOut() =>
      EchoExceptionMapper('Request has timed out', 408);

  /// Creates an [EchoExceptionMapper] representing a `Conflict` exception
  /// (HTTP 409).
  factory EchoExceptionMapper.conflict() => EchoExceptionMapper(
        'Some conflict occured, please check your request',
        409,
      );

  /// Creates an [EchoExceptionMapper] representing an `Internal Server Error`
  /// exception (HTTP 500).
  factory EchoExceptionMapper.internalServerError() => EchoExceptionMapper(
        'Internal server error occured, please try again later',
        500,
      );

  /// Creates an [EchoExceptionMapper] representing a `Not Implemented` exception
  /// (HTTP 501).
  factory EchoExceptionMapper.notImplemented() =>
      EchoExceptionMapper('This feature is not implemented', 501);

  /// Creates an [EchoExceptionMapper] representing a `Remote Server Error`
  /// exception (HTTP 502).
  factory EchoExceptionMapper.remoteServerError() => EchoExceptionMapper(
        'Error occured on remote server, please try again later',
        502,
      );

  /// Creates an [EchoExceptionMapper] representing a `Service Unavailable`
  /// exception (HTTP 503).
  factory EchoExceptionMapper.serviceUnavailable() => EchoExceptionMapper(
        'Service is currently unavailable, please try again later',
        503,
      );

  /// Creates an [EchoExceptionMapper] representing a `Disconnected` exception
  /// (HTTP 510).
  factory EchoExceptionMapper.disconnected() => EchoExceptionMapper(
        'Service is currently unavailable, so disconnection occured. Please try again later',
        510,
      );

  /// Overridden `copyWith` method.
  @override
  EchoException copyWith({String? message, int? code}) =>
      EchoExceptionMapper(message ?? this.message, code ?? this.code);
}

/// Concrete implementation of the [EchoException] class. It represents an
/// exception for Extensions that will be used in the building of the client.
class ExtensionException extends EchoException {
  /// Constructs a [ExtensionException] object by calling the superclass
  /// constructor [EchoException] with the provided `message` and optional
  /// `code`.
  const ExtensionException(super.message, [super.code]);

  /// Factory constructor for creating an [ExtensionException] when a feature
  /// is not implemented. [String] feature contains a text about which feature
  /// is not implemented for this extension.
  factory ExtensionException.notImplementedFeature(
    String extensionName,
    String feature,
  ) =>
      ExtensionException(
        '$feature feature is not implemented for the $extensionName extension',
        404,
      );

  /// Overridden `copyWith` method.
  @override
  EchoException copyWith({String? message, int? code}) =>
      ExtensionException(message ?? this.message, code ?? this.code);
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
      WebSocketException('Unknown WebSocket Error occured');

  /// Thrown when there is an error with the provided URL.
  factory WebSocketException.invalidURL() =>
      WebSocketException('The given WebSocket URL is invalid');

  /// [WebSocketException.timedOut] factory method that creates a
  /// [WebSocketException] object with the error message set to the given
  /// message. This method can be used when a WebSocket connection exceeds the
  /// allowed time limit.
  factory WebSocketException.timedOut() =>
      WebSocketException('WebSocket connection timed out');

  /// Does not need any implementation at the moment.
  @override
  EchoException copyWith({String? message, int? code}) {
    throw UnimplementedError();
  }
}

/// A custom [Exception] class to indicate that there is no protocol defined for
/// the given service or URL.
///
/// This exception should be thrown when the user attempts to use a service that
/// is not defined in to be used within the package.
class ProtocolException extends EchoException {
  const ProtocolException(super.message, [super.code]);

  /// Creates a [ProtocolException] with the given `service`.
  ///
  /// ### Usage
  /// ```dart
  /// try {
  ///   /// Code that throws ProtocolException
  /// } catch (error) {
  ///   log('Error: ${error.toString()});
  /// }
  /// ```
  factory ProtocolException.notDefined(String service) =>
      ProtocolException('Protocol not defined for service "$service"');

  /// Creates a [ProtocolException] to give a message about empty service
  /// string.
  factory ProtocolException.emptyService() =>
      const ProtocolException('The service cannot be empty');

  /// Does not need any implementation at the moment.
  @override
  EchoException copyWith({String? message, int? code}) {
    throw UnimplementedError();
  }
}
