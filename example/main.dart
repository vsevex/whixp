import 'package:whixp/whixp.dart';

void main() {
  final whixp = Whixp(
    jabberID: 'vsevex@localhost/resource',
    password: 'passwd',
    logger: Log(enableWarning: true, enableError: true, includeTimestamp: true),
    internalDatabasePath: 'whixp',
    reconnectionPolicy: RandomBackoffReconnectionPolicy(1, 3),
  );

  /// Reconnect on disconnection.
  whixp.addEventHandler<TransportState>('state', (state) {
    if (state == TransportState.disconnected) whixp.connect();
  });
  whixp.connect();
}
