import 'package:test/test.dart';

import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/roster.dart';

import 'test_base.dart';

void main() {
  late IQ iq;

  setUp(() {
    iq = IQ(generateID: false);
    iq.enable('roster');
  });

  group('iq roster test cases', () {
    test('must properly add items to a roster stanza', () {
      (iq['roster'] as Roster)['items'] = {
        'vsevex@example.com': {
          'name': 'Vsevolod',
          'subscription': 'both',
          'groups': ['cart', 'hella'],
        },
        'alyosha@example.com': {
          'name': 'Alyosha',
          'subscription': 'both',
          'groups': ['gup'],
        },
      };

      check(
        iq,
        '<iq><query xmlns="jabber:iq:roster"><item jid="vsevex@example.com" name="Vsevolod" subscription="both"><group>cart</group><group>hella</group></item><item jid="alyosha@example.com" name="Alyosha" subscription="both"><group>gup</group></item></query></iq>',
      );
    });

    test('get items from roster', () {
      const items = {
        'vsevex@example.com': {
          'lang': '',
          'jid': 'vsevex@example.com',
          'name': 'Vsevolod',
          'subscription': 'both',
          'ask': '',
          'approved': '',
          'groups': ['cart', 'hella'],
        },
        'alyosha@example.com': {
          'lang': '',
          'jid': 'alyosha@example.com',
          'name': 'Alyosha',
          'subscription': 'both',
          'ask': '',
          'approved': '',
          'groups': ['gup'],
        },
      };

      (iq['roster'] as Roster)['items'] = {
        'vsevex@example.com': {
          'name': 'Vsevolod',
          'subscription': 'both',
          'groups': ['cart', 'hella'],
        },
        'alyosha@example.com': {
          'name': 'Alyosha',
          'subscription': 'both',
          'groups': ['gup'],
        },
      };

      expect((iq['roster'] as Roster)['items'], items);
    });

    test('must properly delete roster items', () {
      (iq['roster'] as Roster)['items'] = {
        'vsevex@example.com': {
          'name': 'Vsevolod',
          'subscription': 'both',
          'groups': ['cart', 'hella'],
        },
        'alyosha@example.com': {
          'name': 'Alyosha',
          'subscription': 'both',
          'groups': ['gup'],
        },
      };

      (iq['roster'] as Roster).delete('items');
      check(
        iq,
        '<iq><query xmlns="jabber:iq:roster"/></iq>',
      );
    });
  });
}
