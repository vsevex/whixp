import 'package:whixp/whixp.dart';

void main() {
  final whixp = Whixp(
    jabberID: 'vsevex@localhost/desktop',
    password: 'passwd',
    logger: Log(enableWarning: true, enableError: true, includeTimestamp: true),
    internalDatabasePath: 'whixp',
    reconnectionPolicy: RandomBackoffReconnectionPolicy(1, 3),
  );

  whixp
    ..addEventHandler('streamNegotiated', (_) {
      CSI.sendInactive();
    })
    ..connect();
}
