import 'package:test/test.dart';

import 'package:whixp/src/stanza/message.dart';

void main() {
  group('message stanza test cases', () {
    test('groupchat regression reply stanza should barejid', () {
      final message = Message();

      message['to'] = 'vsevex@localhost';
      message['from'] = 'hall@service.localhost/alyosha';
      message['type'] = 'groupchat';
      message['body'] = 'salam';

      final newMessage = message.replyMessage();
      expect(newMessage['to'], equals('hall@service.localhost'));
    });
  });
}
