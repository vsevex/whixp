import 'dart:developer';

import 'package:whixp/whixp.dart';

void main() {
  const jid = 'vsevex@example.com';
  const password = 'securepassword';
  const name = 'Vsevolod';

  final whixp = Whixp(
    jid,
    password,
    host: 'example.com',
    whitespaceKeepAlive: false,
    logger: Log(enableError: true, enableWarning: true),

    /// change whatever folder name you want, do not use in Flutter
    hivePathName: 'whixpFirst',

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
    ..addEventHandler('streamNegotiated', (_) {
      whixp.sendPresence();
      if (!whixp.clientRoster.hasJID('alyosha@example.com')) {
        (whixp.clientRoster['alyosha@example.com'] as RosterItem).subscribe();
      }
    })
    ..addEventHandler<Presence>('rosterSubscriptionRequest', (request) {
      if (request!.from == JabberID('alyosha@example.com')) {
        (whixp.clientRoster['alyosha@example.com'] as RosterItem).authorize();
      }
    })
    ..addEventHandler<Message>('message', (message) {
      if (message != null) {
        log('Message from: ${message.from!.bare}');
      }
    })
    ..addEventHandler<Form>('register', (_) {
      final response = whixp.makeIQSet();
      final register = response['register'] as Register;

      register['username'] = JabberID(jid).user;
      register['password'] = password;
      register['name'] = name;

      response.sendIQ(callback: (iq) => log('Registered!!!'));
    });

  whixp.connect();
}
