import 'package:echo/echo.dart';

Future<void> main() async {
  final echo = Echo(
    service: 'ws://localhost:5443/ws',
    jid: JabberID(
      'user',
      domain: 'localhost',
      resource: 'mobile',
    ),
    password: 'somepsw',
  );

  echo.connect();
}
