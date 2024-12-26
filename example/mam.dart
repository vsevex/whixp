import 'package:whixp/whixp.dart';

void main() {
  final whixp = Whixp(
    jabberID: 'asdf@localhost',
    password: 'passwd',
    logger: Log(
      enableWarning: true,
      enableError: true,
      includeTimestamp: true,
    ),
    internalDatabasePath: 'whixp',
  );

  whixp
    ..addEventHandler('streamNegotiated', (_) {
      // for (int i = 1; i <= 2; i++) {
      //   final message = Message(
      //     subject: "normal",
      //     body: "hmm trying something heehe * $i",
      //   )..to = JabberID("asdfasdf@localhost");
      //
      //   whixp.send(message.makeMarkable);
      // }

      return paginationRequest();
    })
    ..addEventHandler<Message>('message', (message) {
      final result = message?.get<MAMResult>();

      if (result?.isNotEmpty ?? false) {
        for (final stanza in result!) {
          final forwarded = stanza.forwarded;
          if (forwarded?.delay?.stamp != null) {
            Log.instance.info(forwarded!.delay!.stamp!);
          }
          Log.instance.info("marked: ${forwarded?.actual?.isMarked}");
          Log.instance.info(
            "from: ${forwarded?.actual?.from?.username} \t to: ${forwarded?.actual?.to?.username}",
          );

          Log.instance.info(
            "type: ${forwarded?.actual?.subject} \t value: ${forwarded?.actual?.body}",
          );
        }
      }
    });
  whixp.connect();
}

/// Recursively request messages from the archive.
Future<void> paginationRequest({String? lastItem}) async {
  const mam = MAM();
  final result = await MAM.queryArchive(
    pagination: RSMSet(
      max: 25,
      // after: lastItem,
      before: lastItem ?? "",
    ),
    filter: mam.createFilter(
      wth: "asdfasdf@localhost",
    ),
    flipPage: true,
  );

  final fin = result.payload as MAMFin?;
  final last = fin?.last?.lastItem;
  Log.instance.warning(
    "complete: ${fin?.complete}",
  );
  Log.instance.info("first cursor: $last");
  if (last?.isEmpty ?? true) return;
  if (fin != null && !fin.complete && last != null) {
    return paginationRequest(
      lastItem: last,
    );
  }
  // return paginationRequest(lastItem: last);
}
