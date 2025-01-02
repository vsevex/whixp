import 'package:whixp/whixp.dart';

void main() {
  final whixp = Whixp(
    jabberID: 'vsevex@localhost/resource',
    password: 'passwd',
    logger: Log(
      enableWarning: true,
      enableError: true,
      includeTimestamp: true,
    ),
    internalDatabasePath: 'whixp',
  );

  whixp
    ..addEventHandler('streamNegotiated', (_) => getInbox())
    ..addEventHandler<Message>('message', (message) {
      final result = message?.get<InboxResult>();
      if (result?.isNotEmpty ?? false) {
        for (final stanza in result!) {
          final forwarded = stanza.forwarded;
          if (forwarded?.delay?.stamp != null) {
            Log.instance.info(forwarded!.delay!.stamp!);
          }
          Log.instance.info("marked: ${forwarded?.actual?.isMarked}");
          Log.instance.info(
            "box: ${stanza.box} \t archive: ${stanza.archive} \t mute: ${stanza.mute}",
          );
          Log.instance.info(
            "from: ${forwarded?.actual?.from?.username} \t to: ${forwarded?.actual?.to?.username}",
          );

          Log.instance.info("unread: ${stanza.unread}");

          Log.instance.info(
            "type: ${forwarded?.actual?.subject} \t value: ${forwarded?.actual?.body}",
          );
        }
      }
    });
  whixp.connect();
}

String? globalLast;

Future<void> getInbox({
  String? lastItem,
}) async {
  globalLast = null;
  final result = await Inbox.queryInbox(
    pagination: RSMSet(
      max: 25,
      after: lastItem,
    ),
  );

  final fin = result.payload as InboxFin?;
  final last = fin?.last?.lastItem;
  Log.instance.warning(
    "active-conversations: ${fin?.activeConversation}",
  );
  Log.instance.warning(
    "unread: ${fin?.unreadMessages}",
  );
  Log.instance.warning(
    "cursor: $last",
  );

  if (last != null && last != globalLast) {
    getInbox(
      lastItem: last,
    );
  }
}
