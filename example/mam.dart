import 'package:whixp/whixp.dart';

void main() {
  final whixp = Whixp(
    jabberID: 'vsevex@localhost',
    password: 'vesevu13',
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

      return paginationRequest(whixp.transport);
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
Future<void> paginationRequest(Transport transport, {String? lastItem}) async {
  const mam = MAM();

  try {
    final result = await MAM.queryArchive(
      transport,
      pagination: RSMSet(
        max: 25,
        // after: lastItem,
        before: lastItem ?? "",
      ),
      filter: mam.createFilter(
        wth: "vsevex@localhost",
      ),
      flipPage: true,
      failureCallback: (error) {
        Log.instance.error(
          'MAM query failed: ${error.reason} - ${error.text ?? "No error text"}',
        );
      },
    );

    // Check for errors first
    if (result.type == 'error' || result.error != null) {
      Log.instance.error(
        'MAM query returned error: ${result.error?.reason ?? "unknown"} - ${result.error?.text ?? ""}',
      );
      return;
    }

    // Safe cast: only cast to MAMFin if it's actually a MAMFin
    final fin = result.payload is MAMFin ? result.payload! as MAMFin : null;

    if (fin == null) {
      Log.instance.warning(
        'MAM query did not return MAMFin. Payload type: ${result.payload?.runtimeType}',
      );
      return;
    }

    final last = fin.last?.lastItem;
    Log.instance.warning(
      "complete: ${fin.complete}",
    );
    Log.instance.info("first cursor: $last");
    if (last?.isEmpty ?? true) return;
    if (!fin.complete && last != null) {
      return paginationRequest(
        transport,
        lastItem: last,
      );
    }
  } catch (e, stackTrace) {
    Log.instance.error('Error in paginationRequest: $e');
    Log.instance.error('Stack trace: $stackTrace');
  }
}
