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

    /// accept acked stanzas
    ..addEventHandler<Stanza>('ackedStanza', (stanza) {
      if (stanza is Message) {
        /// Get stanza ID from the [Message].
        final stanzaIDs = stanza.get<StanzaID>();
        if (stanzaIDs.isNotEmpty) {
          Log.instance.warning('Stanza ID: ${stanzaIDs.first.id}');
        }
      }
    })

    /// Add message handler to accept messages from others.
    ..addEventHandler<Message>('message', (message) {
      final messageIsFrom = message?.from?.bare;
      final body = message?.body;
      if (messageIsFrom?.isNotEmpty ?? false) {
        Log.instance.warning('Message $body is from: $messageIsFrom');
      } else {
        Log.instance.warning('Message $body is from unknown');
      }
    })
    ..addEventHandler('streamNegotiated', (_) {
      /// send initial presence after stream is negotiated
      whixp.sendPresence();
    })
    ..connect();

  /// send unavailable presence
  whixp.sendPresence(type: 'unavailable');

  /// send first message to the receiver
  whixp.sendMessage(JabberID('alyosha@localhost'), body: 'Hi from vsevex');
}
