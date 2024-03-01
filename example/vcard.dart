import 'package:whixp/whixp.dart';

void main() {
  final whixp = Whixp(
    'vsevex@example.com/desktop',
    'passwd',
    host: 'example.com',
    logger: Log(enableError: true, enableWarning: true),
    provideHivePath: true,
  );

  final vCard = VCardTemp();
  whixp.registerPlugin(vCard);
  whixp.connect();
  whixp.addEventHandler('streamNegotiated', (_) async {
    final stanza = VCardTempStanza();
    stanza['FN'] = 'Vsevolod';
    stanza['NICKNAME'] = 'vsevex';
    vCard.publish(stanza);
  });
}
