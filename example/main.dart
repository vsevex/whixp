import 'package:echox/echox.dart';

Future<void> main() async {
  final echox = EchoX(
    service: 'ws://localhost:5443/ws',
    jid: JabberID(
      'user',
      domain: 'localhost',
      resource: 'mobile',
    ),
    password: 'somepsw',
  );

  echox.connect();
}
