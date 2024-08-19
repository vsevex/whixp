import 'package:whixp/whixp.dart';

void main() {
  final whixp = Whixp(
    jabberID: 'vsevex@localhost',
    password: 'vesevu13',
    logger: Log(enableWarning: true, enableError: true, includeTimestamp: true),
    internalDatabasePath: 'whixp',
  );

  whixp
    ..addEventHandler('streamNegotiated', (_) {
      for (int i = 1; i <= 100; i++) {
        whixp.sendMessage(JabberID('alyosha@loalhost'), body: 'Message no: $i');
      }

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
        }
      }
    });
  whixp.connect();
}

/// Recursively request messages from the archive.
Future<void> paginationRequest({String? lastItem}) async {
  final result =
      await MAM.queryArchive(pagination: RSMSet(max: 20, after: lastItem));

  final fin = result.payload as MAMFin?;
  final last = fin?.last?.lastItem;
  if (last?.isEmpty ?? true) return;
  return paginationRequest(lastItem: last);
}
