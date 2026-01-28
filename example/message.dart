import 'package:whixp/whixp.dart';

void main() {
  final whixp = Whixp(
    jabberID: 'vsevex@localhost',
    password: 'passwd',
    logger: Log(enableWarning: true, enableError: true, includeTimestamp: true),
    internalDatabasePath: 'whixp',
    reconnectionPolicy: RandomBackoffReconnectionPolicy(1, 3),
  );

  whixp
    ..addEventHandler('streamNegotiated', (_) {
      whixp.sendPresence();

      /// Sending sample message.
      whixp.sendMessage(JabberID('anar@localhost'), body: 'First message');

      /// Sending marked message.
      const id = StanzaID('random-id');
      whixp.sendMessage(
        JabberID('alyosha@localhost'),
        body: 'Second message requesting displayed marker',
        requestDisplayedInformation: true,
        payloads: [id],
      );
    })
    ..addEventHandler<Message>('message', (message) {
      if (message == null) return;
      if (message.isMarked) {
        final messageIDs = message.get<StanzaID>();
        if (messageIDs.isNotEmpty && message.from != null) {
          final id = messageIDs.first.id;
          whixp.sendDisplayedMessage(message.from!, messageID: id);
        }
      }
    });
  whixp.connect();
}
