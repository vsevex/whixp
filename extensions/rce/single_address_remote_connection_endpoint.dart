import 'dart:io' as io;

import 'remote_connection_endpoint.dart';

/// Represents a single address remote connection endpoint.
///
/// This class represents a connection which has a single IP address and port
/// number. This type of endpoint is often used for simple applications that
/// only need to connect to a single server.
///
/// Note: This type of remote connection endpoints are reliable because they
/// are not affected by network failures that affect multiple IP addresses.
abstract class SingleAddressRemoteConnectionEndpoint
    extends RemoteConnectionEndpoint {
  /// The Internet address associated with the remote connection.
  io.InternetAddress get internetAddress;

  /// Returns a list containing the single Internet address associated with the
  /// remote connection.
  @override
  List<io.InternetAddress> get internetAddresses =>
      List.filled(1, internetAddress);

  @override
  String get description => 'Single Address Remote Connection Endpoint';
}
