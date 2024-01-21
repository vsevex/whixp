import 'dart:developer';

import 'package:whixp/whixp.dart';

void main() {
  final whixp = Whixp(
    'vsevex@example.com/mobile',
    'passwd',
    host: 'example.com',
    logger: Log(enableError: true, enableWarning: true),
  );

  final disco = ServiceDiscovery();
  final pubsub = PubSub();
  final rsm = RSM();

  whixp
    ..registerPlugin(disco)
    ..registerPlugin(rsm)
    ..registerPlugin(pubsub);

  whixp.connect();
  whixp.addEventHandler('sessionStart', (_) async {
    whixp.getRoster();
    whixp.sendPresence();

    final payload = AtomEntry();
    payload['title'] = "Ink & Echoes: A Writer's Prelude";
    payload['summary'] =
        'oin the adventure where every word is a brushstroke, crafting a spellbinding tapestry that beckons readers into the magical realm of storytelling.';

    await pubsub.publish(
      JabberID('pubsub.example.com'),
      'senatus',
      payload: payload,
      callback: (iq) => log('$payload is published!'),
    );
  });
}
