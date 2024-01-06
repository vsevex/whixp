import 'package:test/test.dart';

import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/roster.dart';
import 'package:whixp/src/stream/base.dart';

import 'test_base.dart';

void main() {
  late final IQ iq;
  late final Roster roster;
  late final RosterItem item;

  setUpAll(() {
    iq = IQ(generateID: false);
    roster = Roster();
    item = RosterItem();

    registerStanzaPlugin(iq, roster);
    registerStanzaPlugin(roster, item, iterable: true);
  });

  group('iq roster test cases', () {
    test('must properly add items to a roster stanza', () {
      (iq['roster'] as XMLBase)['items'] = {
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
        iq['roster'] as XMLBase,
        '<query xmlns="jabber:iq:roster"><item jid="vsevex@example.com" name="Vsevolod" subscription="both"><group>cart</group><group>hella</group></item><item jid="alyosha@example.com" name="Alyosha" subscription="both"><group>gup</group></item></query>',
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

      (iq['roster'] as XMLBase)['items'] = {
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

      expect((iq['roster'] as XMLBase)['items'], items);
    });

    test('must properly delete roster items', () {
      (iq['roster'] as XMLBase)['items'] = {
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

      (iq['roster'] as XMLBase).delete('items');

      check(
        iq['roster'] as XMLBase,
        '<query xmlns="jabber:iq:roster"/>"',
      );
    });
  });
}
