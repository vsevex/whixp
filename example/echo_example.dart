import 'dart:developer';

import 'package:echo/echo.dart';

Future<void> main() async {
  final echo = Echo(service: 'ws://localhost:7070/ws');
  await echo.connect(
    jid: 'vsevex@localhost',
    password: 'somepsw',
    callback: (status) async {
      if (status == EchoStatus.connected) {
        log('Connection Established');
      } else if (status == EchoStatus.disconnected) {
        log('Connection Terminated');
      }
    },
  );
}
