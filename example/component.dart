import 'package:whixp/whixp.dart';

void main() {
  final component = WhixpComponent(
    'push.example.com',
    secret: 'pushnotifications',
    host: 'example.com',
    port: 5275,
    logger: Log(enableError: true, enableWarning: true),
    provideHivePath: true,
  );
  component.connect();
}
