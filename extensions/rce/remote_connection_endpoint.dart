import 'dart:io' as io;

/// Represents a remote connection endpoint.
///
/// ### Usage
/// ```dart
/// final endpoint = RCE extends RemoteConnectionEndpoint;
/// print(endpoint.host); /// Output: 192.168.0.1
/// ```
abstract class RemoteConnectionEndpoint {
  /// [String] type `host` representer.
  String get host;

  /// Unassigned 16-bit integer `port` representer.
  int get port;

  /// The [List] of available internet addresses.
  List<dynamic> get internetAddresses;

  /// The [String] representation of the description which needs to be
  /// initialized when passing [RCE] object.
  String get description;
}

/// Represents the coupling of a [RemoteConnectionEndpoint] with an
/// [io.InternetAddress].
class SocketAddressCoupling<RCE extends RemoteConnectionEndpoint> {
  /// Creates a new [SocketAddressCoupling] instance.
  ///
  /// The [connectionEndpoint] is used to retrieve the port, and the [address]
  /// is used to create [io.InternetAddress].
  SocketAddressCoupling(this.connectionEndpoint, String address) {
    port = connectionEndpoint.port;
    this.address = io.InternetAddress(
      address,
      type: io.InternetAddressType.IPv4,
    );
  }

  /// The remote connection endpoint.
  final RCE connectionEndpoint;

  /// The Internet address associated with the remote connection.
  late final io.InternetAddress address;

  /// The port of the remote connection.
  late final int port;

  /// final coupling = SocketAddressCoupling(RCE, '192.168.0.1');
  /// print(coupling); /// Output: Remote endpoint description + (192.168.0.1)
  @override
  String toString() => ''' ${connectionEndpoint.description} + ( $address ) ''';
}
