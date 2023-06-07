import 'remote_connection_endpoint.dart';

/// Represents an exception that occured during a remote connection.
class RemoteConnectionException<RCE extends RemoteConnectionEndpoint> {
  /// Creates a new [RemoteConnectionException] instance.
  ///
  /// The [address] represents the socket address coupling where the exception
  /// occured. And the [exception] represents the exception that occured during
  /// the connection.
  RemoteConnectionException(
    this.address,
    this.exception,
  );

  /// The socket address coupling where the exception occured.
  late final SocketAddressCoupling<RCE> address;

  /// The exception that occured during the remote connection.
  late Exception exception;

  /// Returns an error message describing the remote connection exception.
  String get errorMessage => ''' \$$address failed because $exception''';
}
