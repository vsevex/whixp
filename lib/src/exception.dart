/// The given given class is a custom written [Exception] class for [EchoX].
///
/// This abstract class provides a way to encapsulate all possible exceptions
/// accross the application.
///
/// ### Example:
/// class SomeException extends EchoException {
///
/// }
abstract class EchoException implements Exception {
  /// Constructs an [EchoException] object with the provided [message] and
  /// [code].
  const EchoException(this.message, [this.code]);

  /// An optional [int] representing the error code associated with the
  /// exception. If not provided, it defaults to `null`.
  final int? code;

  /// A [String] containing the error message associated with the exception.
  final String message;

  @override
  String toString() =>
      '''Exception: $message${code != null ? ' (code: $code)' : ''} ''';
}

// /// [EchoExceptionMapper] is a custom exception class that extends [EchoException].
// /// It provides a set of factory methods for creating different types of
// /// exceptions commonly encountered in an application, along with their
// /// corresponding HTTP status codes.
// ///
// /// Example:
// /// ```dart
// /// throw EchoExceptionMapper.notFound();
// /// ```
// class EchoExceptionMapper extends EchoException {
//   /// Constructs an [EchoExceptionMapper] with the given [message] and an optional
//   /// [code].
//   EchoExceptionMapper(super.message, [super.code]);

//   /// Creates an [EchoExceptionMapper] representing a `Bad Request` exception
//   /// (HTTP 400).
//   factory EchoExceptionMapper.badRequest() =>
//       EchoExceptionMapper('Bad Request has been made', 400);

//   /// Creates an [EchoExceptionMapper] representing a `Not Authorized` exception
//   /// (HTTP 401).
//   factory EchoExceptionMapper.notAuthorized() =>
//       EchoExceptionMapper('You are not authorized to do this action', 401);

//   /// Creates an [EchoExceptionMapper] representing a `Forbidden` exception
//   /// (HTTP 403).
//   factory EchoExceptionMapper.forbidden() =>
//       EchoExceptionMapper('Forbidden', 403);

//   /// Creates an [EchoExceptionMapper] representing a `Not Found` exception
//   /// (HTTP 404).
//   factory EchoExceptionMapper.notFound() =>
//       EchoExceptionMapper('Nothing found for your request', 404);

//   /// Creates an [EchoExceptionMapper] representing a `Not Allowed` exception
//   /// (HTTP 405).
//   factory EchoExceptionMapper.notAllowed() =>
//       EchoExceptionMapper('You are not allowed to do this action', 405);

//   /// Creates an [EchoExceptionMapper] representing a `Registration Required`
//   /// exception (HTTP 407).
//   factory EchoExceptionMapper.registrationRequired() => EchoExceptionMapper(
//         'You need to register in order to make this request',
//         407,
//       );

//   /// Creates an [EchoExceptionMapper] representing a `Request Timed Out` exception
//   /// (HTTP 408).
//   factory EchoExceptionMapper.requestTimedOut() =>
//       EchoExceptionMapper('Request has timed out', 408);

//   /// Creates an [EchoExceptionMapper] representing a `Conflict` exception
//   /// (HTTP 409).
//   factory EchoExceptionMapper.conflict() => EchoExceptionMapper(
//         'Some conflict occured, please check your request',
//         409,
//       );

//   /// Creates an [EchoExceptionMapper] representing an `Internal Server Error`
//   /// exception (HTTP 500).
//   factory EchoExceptionMapper.internalServerError() => EchoExceptionMapper(
//         'Internal server error occured, please try again later',
//         500,
//       );

//   /// Creates an [EchoExceptionMapper] representing a `Not Implemented` exception
//   /// (HTTP 501).
//   factory EchoExceptionMapper.notImplemented() =>
//       EchoExceptionMapper('This feature is not implemented', 501);

//   /// Creates an [EchoExceptionMapper] representing a `Remote Server Error`
//   /// exception (HTTP 502).
//   factory EchoExceptionMapper.remoteServerError() => EchoExceptionMapper(
//         'Error occured on remote server, please try again later',
//         502,
//       );

//   /// Creates an [EchoExceptionMapper] representing a `Service Unavailable`
//   /// exception (HTTP 503).
//   factory EchoExceptionMapper.serviceUnavailable() => EchoExceptionMapper(
//         'Service is currently unavailable, please try again later',
//         503,
//       );

//   /// Creates an [EchoExceptionMapper] representing a `Disconnected` exception
//   /// (HTTP 510).
//   factory EchoExceptionMapper.disconnected() => EchoExceptionMapper(
//         'Service is currently unavailable, so disconnection occured. Please try again later',
//         510,
//       );
// }

/// A custom [Exception] class to indicate that there is no protocol defined for
/// the given service or URL.
///
/// This exception should be thrown when the user attempts to use a service that
/// is not defined in to be used within the package.
class TransportException extends EchoException {
  const TransportException(super.message, [super.code]);

  /// Creates a [TransportException] to give a message about empty service
  /// string.
  factory TransportException.emptyService() =>
      const TransportException('The service cannot be empty');
}
