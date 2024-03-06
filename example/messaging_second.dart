import 'dart:developer';

import 'package:whixp/whixp.dart';

void main() {
  const jid = 'alyosha@example.com';
  const password = 'othersecurepassword';
  const name = 'Alyosha';

  final whixp = Whixp(
    jid,
    password,
    host: 'example.com',
    whitespaceKeepAlive: false,
    logger: Log(enableError: true, enableWarning: true),

    /// change whatever folder name you want, do not use in Flutter
    hivePathName: 'whixpSecond',

    /// just use in Dart projects
    provideHivePath: true,
  );

  final ping = Ping(interval: 60, keepalive: true);
  final register = InBandRegistration();

  whixp
    ..clientRoster.autoAuthorize = false
    ..clientRoster.autoSubscribe = false
    ..registerPlugin(register)
    ..registerPlugin(ping)
    ..addEventHandler('streamNegotiated', (_) => whixp.sendPresence())
    ..addEventHandler<Presence>('rosterSubscriptionRequest', (request) {
      if (request!.from == JabberID('vsevex@example.com')) {
        (whixp.clientRoster['vsevex@example.com'] as RosterItem).authorize();
      }
    })
    ..addEventHandler<Presence>('presenceAvailable', (data) async {
      if (data!.from!.bare == 'vsevex@example.com') {
        await Future.delayed(const Duration(seconds: 5), () {
          whixp.sendMessage(
            JabberID('vsevex@example.com'),
            messageBody: 'Hello from $name!!!',
          );
        });
      }
    })
    ..addEventHandler<Form>('register', (_) {
      final response = whixp.makeIQSet();
      final register = response['register'] as Register;

      register['username'] = JabberID(jid).user;
      register['password'] = password;
      register['name'] = name;

      response.sendIQ(
        callback: (iq) {
          (whixp.clientRoster['vsevex@example.com'] as RosterItem).subscribe();
          log('Registered!!!');
        },
      );
    });

  whixp.connect();
}
