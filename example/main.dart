import 'package:whixp/whixp.dart';

void main() {
  final whixp = Whixp(
    'alyosha@example.com/desktop',
    'alyosha13',
    host: 'example.com',
    logger: Log(enableError: true, enableWarning: true),
  );

  whixp.connect();
  whixp.addEventHandler('sessionStart', (_) {
    whixp.getRoster();
    whixp.sendPresence();
  });
}
