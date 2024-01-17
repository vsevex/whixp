import 'package:dartz/dartz.dart';
import 'package:test/test.dart';

import 'package:whixp/src/plugins/disco/disco.dart';
import 'package:whixp/src/stanza/iq.dart';

import 'test_base.dart';

void main() {
  late IQ iq;

  IQ copyIQ(IQ iq) => IQ(generateID: false, element: iq.element);

  setUp(() => iq = IQ(generateID: false));

  group('disco extension stanza creating and manipulating test cases', () {
    test('disco#info query without node', () {
      (iq['disco_info'] as DiscoInformationAbstract)['node'] = '';

      check(
        copyIQ(iq),
        '<iq><query xmlns="http://jabber.org/protocol/disco#info"/></iq>',
      );
    });

    test('disco#info query with a node', () {
      (iq['disco_info'] as DiscoInformationAbstract)['node'] = 'cart';

      check(
        copyIQ(iq),
        '<iq><query xmlns="http://jabber.org/protocol/disco#info" node="cart"/></iq>',
      );
    });

    test('must properly add identity to disco#info', () {
      (iq['disco_info'] as DiscoInformationAbstract)
          .addIdentity('conference', 'text', name: 'room', language: 'en');

      check(
        copyIQ(iq),
        '<iq><query xmlns="http://jabber.org/protocol/disco#info"><identity category="conference" type="text" name="room" xml:lang="en"/></query></iq>',
      );
    });

    test(
      'must keep first identity when adding multiple copies of the same category and type combination',
      () {
        (iq['disco_info'] as DiscoInformationAbstract)
            .addIdentity('conference', 'text', name: 'MUC');
        (iq['disco_info'] as DiscoInformationAbstract)
            .addIdentity('conference', 'text', name: 'room');

        check(
          copyIQ(iq),
          '<iq><query xmlns="http://jabber.org/protocol/disco#info"><identity category="conference" name="MUC" type="text"/></query></iq>',
        );
      },
    );

    test('previous test, but language property added', () {
      (iq['disco_info'] as DiscoInformationAbstract)
          .addIdentity('conference', 'text', name: 'MUC', language: 'en');
      (iq['disco_info'] as DiscoInformationAbstract)
          .addIdentity('conference', 'text', name: 'room', language: 'en');

      check(
        copyIQ(iq),
        '<iq><query xmlns="http://jabber.org/protocol/disco#info"><identity category="conference" name="MUC" type="text" xml:lang="en"/></query></iq>',
      );
    });

    test('remove identites from a disco#info stanza', () {
      (iq['disco_info'] as DiscoInformationAbstract)
        ..addIdentity('client', 'pc')
        ..addIdentity('client', 'bot')
        ..deleteIdentity('client', 'bot');

      check(
        copyIQ(iq),
        '<iq><query xmlns="http://jabber.org/protocol/disco#info"><identity category="client" type="pc"/></query></iq>',
      );
    });

    test('remove identities from a disco#info stanza with language', () {
      (iq['disco_info'] as DiscoInformationAbstract)
        ..addIdentity('client', 'pc')
        ..addIdentity('client', 'bot', language: 'az')
        ..deleteIdentity('client', 'bot');

      check(
        copyIQ(iq),
        '<iq><query xmlns="http://jabber.org/protocol/disco#info"><identity category="client" type="bot" xml:lang="az"/><identity category="client" type="pc"/></query></iq>',
      );
    });

    test('remove all identities from a disco#info stanza', () {
      (iq['disco_info'] as DiscoInformationAbstract)
        ..addIdentity('client', 'pc', name: 'PC')
        ..addIdentity('client', 'pc', language: 'az')
        ..addIdentity('client', 'bot');

      (iq['disco_info'] as DiscoInformationAbstract).delete('identities');
      check(
        copyIQ(iq),
        '<iq><query xmlns="http://jabber.org/protocol/disco#info"/></iq>',
      );
    });

    test('remove all identities with provided language from disco#info stanza',
        () {
      (iq['disco_info'] as DiscoInformationAbstract)
        ..addIdentity('client', 'pc', name: 'PC')
        ..addIdentity('client', 'pc', language: 'az')
        ..addIdentity('client', 'bot');

      (iq['disco_info'] as DiscoInformationAbstract)
          .deleteIdentities(language: 'az');
    });

    test('must add multiple identities at once', () {
      const identities = <DiscoveryIdentity>[
        DiscoveryIdentity('client', 'pc', name: 'PC', language: 'az'),
        DiscoveryIdentity('client', 'bot', name: 'Bot'),
      ];

      (iq['disco_info'] as DiscoInformationAbstract).setIdentities(identities);

      check(
        copyIQ(iq),
        '<iq><query xmlns="http://jabber.org/protocol/disco#info"><identity category="client" name="Bot" type="bot"/><identity category="client" name="PC" type="pc" xml:lang="az"/></query></iq>',
      );
    });

    test('selectively replace identities based on language', () {
      (iq['disco_info'] as DiscoInformationAbstract)
        ..addIdentity('client', 'pc', language: 'en')
        ..addIdentity('client', 'pc', language: 'az')
        ..addIdentity('client', 'bot', language: 'ru');

      const identities = <DiscoveryIdentity>[
        DiscoveryIdentity('client', 'pc', name: 'Bot', language: 'ru'),
        DiscoveryIdentity('client', 'bot', name: 'Bot', language: 'en'),
      ];

      (iq['disco_info'] as DiscoInformationAbstract)
          .setIdentities(identities, language: 'ru');

      check(
        copyIQ(iq),
        '<iq><query xmlns="http://jabber.org/protocol/disco#info"><identity category="client" name="Bot" type="bot" xml:lang="en"/><identity category="client" name="Bot" type="bot" xml:lang="ru"/><identity category="client" type="pc" xml:lang="az"/><identity category="client" type="pc" xml:lang="en"/></query></iq>',
      );
    });

    test('getting all identities from a disco#info stanza', () {
      (iq['disco_info'] as DiscoInformationAbstract)
        ..addIdentity('client', 'pc')
        ..addIdentity('client', 'pc', language: 'az')
        ..addIdentity('client', 'pc', language: 'ru')
        ..addIdentity('client', 'pc', language: 'en');

      expect(
        (iq['disco_info'] as DiscoInformationAbstract)['identities'],
        equals(<DiscoveryIdentity>{
          const DiscoveryIdentity('client', 'pc', language: 'en'),
          const DiscoveryIdentity('client', 'pc', language: 'ru'),
          const DiscoveryIdentity('client', 'pc', language: 'az'),
          const DiscoveryIdentity('client', 'pc'),
        }),
      );
    });

    test('getting all identities of a given language from a disco#info stanza',
        () {
      (iq['disco_info'] as DiscoInformationAbstract)
        ..addIdentity('client', 'pc')
        ..addIdentity('client', 'pc', language: 'az')
        ..addIdentity('client', 'pc', language: 'ru')
        ..addIdentity('client', 'pc', language: 'en');

      expect(
        (iq['disco_info'] as DiscoInformationAbstract)
            .getIdentities(language: 'en'),
        equals({const DiscoveryIdentity('client', 'pc', language: 'en')}),
      );
    });

    test('must correctly add feature to disco#info', () {
      (iq['disco_info'] as DiscoInformationAbstract)
        ..addFeature('foo')
        ..addFeature('bar');

      check(
        copyIQ(iq),
        '<iq><query xmlns="http://jabber.org/protocol/disco#info"><feature var="foo"/><feature var="bar"/></query></iq>',
      );
    });

    test('must correctly handle adding duplicate feature to disco#info', () {
      (iq['disco_info'] as DiscoInformationAbstract)
        ..addFeature('foo')
        ..addFeature('bar')
        ..addFeature('foo');

      check(
        copyIQ(iq),
        '<iq><query xmlns="http://jabber.org/protocol/disco#info"><feature var="foo"/><feature var="bar"/></query></iq>',
      );
    });

    test('must properly remove feature from disco', () {
      (iq['disco_info'] as DiscoInformationAbstract)
        ..addFeature('foo')
        ..addFeature('bar')
        ..addFeature('foo');

      (iq['disco_info'] as DiscoInformationAbstract).deleteFeature('foo');

      check(
        copyIQ(iq),
        '<iq><query xmlns="http://jabber.org/protocol/disco#info"><feature var="bar"/></query></iq>',
      );
    });

    test('get all features from disco#info', () {
      (iq['disco_info'] as DiscoInformationAbstract)
        ..addFeature('foo')
        ..addFeature('bar')
        ..addFeature('foo');

      final features =
          (iq['disco_info'] as DiscoInformationAbstract)['features'];
      expect(features, equals({'foo', 'bar'}));
    });

    test('must properly remove all features from a disco#info', () {
      (iq['disco_info'] as DiscoInformationAbstract)
        ..addFeature('foo')
        ..addFeature('bar')
        ..addFeature('baz');

      (iq['disco_info'] as DiscoInformationAbstract).delete('features');
      check(
        copyIQ(iq),
        '<iq><query xmlns="http://jabber.org/protocol/disco#info"/></iq>',
      );
    });

    test('add multiple features at once', () {
      final features = <String>{'foo', 'bar', 'baz'};

      (iq['disco_info'] as DiscoInformationAbstract)['features'] = features;

      check(
        copyIQ(iq),
        '<iq><query xmlns="http://jabber.org/protocol/disco#info"><feature var="foo"/><feature var="bar"/><feature var="baz"/></query></iq>',
      );
    });
  });

  group('discovery items test cases', () {
    test('must properly add features to disco#info', () {
      (iq['disco_items'] as DiscoItemsAbstract)
        ..addItem('vsevex@example.com')
        ..addItem('vsevex@example.com', node: 'foo')
        ..addItem('vsevex@example.com', node: 'bar', name: 'cart');

      check(
        iq,
        '<iq><query xmlns="http://jabber.org/protocol/disco#items"><item jid="vsevex@example.com"/><item jid="vsevex@example.com" node="foo"/><item jid="vsevex@example.com" name="cart" node="bar"/></query></iq>',
        useValues: false,
      );
    });

    test('add items with the same JID without any nodes', () {
      (iq['disco_items'] as DiscoItemsAbstract)
        ..addItem('vsevex@example.com', name: 'cart')
        ..addItem('vsevex@example.com', name: 'hert');

      check(
        iq,
        '<iq><query xmlns="http://jabber.org/protocol/disco#items"><item jid="vsevex@example.com" name="cart"/></query></iq>',
        useValues: false,
      );
    });

    test('add items with the same JID nodes', () {
      (iq['disco_items'] as DiscoItemsAbstract)
        ..addItem('vsevex@example.com', name: 'cart', node: 'foo')
        ..addItem('vsevex@example.com', name: 'hert', node: 'foo');

      check(
        iq,
        '<iq><query xmlns="http://jabber.org/protocol/disco#items"><item jid="vsevex@example.com" name="cart" node="foo"/></query></iq>',
        useValues: false,
      );
    });

    test('remove items without nodes from stanza', () {
      (iq['disco_items'] as DiscoItemsAbstract)
        ..addItem('vsevex@example.com')
        ..addItem('vsevex@example.com', node: 'foo')
        ..addItem('alyosha@example.com')
        ..removeItem('vsevex@example.com');

      check(
        iq,
        '<iq><query xmlns="http://jabber.org/protocol/disco#items"><item jid="vsevex@example.com" node="foo"/><item jid="alyosha@example.com"/></query></iq>',
        useValues: false,
      );
    });

    test('remove items with nodes from stanza', () {
      (iq['disco_items'] as DiscoItemsAbstract)
        ..addItem('vsevex@example.com')
        ..addItem('vsevex@example.com', node: 'foo')
        ..addItem('alyosha@example.com')
        ..removeItem('vsevex@example.com', node: 'foo');

      check(
        iq,
        '<iq><query xmlns="http://jabber.org/protocol/disco#items"><item jid="vsevex@example.com"/><item jid="alyosha@example.com"/></query></iq>',
        useValues: false,
      );
    });

    test('must properly get all items', () {
      (iq['disco_items'] as DiscoItemsAbstract)
        ..addItem('vsevex@example.com')
        ..addItem('vsevex@example.com', node: 'foo')
        ..addItem('alyosha@example.com', node: 'bar', name: 'cart');

      expect(
        ((iq['disco_items']) as DiscoItemsAbstract)['items'],
        equals(<Tuple3<String, String, String>>{
          const Tuple3('vsevex@example.com', '', ''),
          const Tuple3('vsevex@example.com', 'foo', ''),
          const Tuple3('alyosha@example.com', 'bar', 'cart'),
        }),
      );
    });

    test('must properly remove all items', () {
      (iq['disco_items'] as DiscoItemsAbstract)
        ..addItem('vsevex@example.com')
        ..addItem('vsevex@example.com', node: 'foo')
        ..addItem('alyosha@example.com', node: 'bar', name: 'cart');

      (iq['disco_items'] as DiscoItemsAbstract).removeItems();

      check(
        iq,
        '<iq><query xmlns="http://jabber.org/protocol/disco#items"/></iq>',
        useValues: false,
      );
    });

    test('must properly set all items', () {
      final items = <SingleDiscoveryItem>{
        const SingleDiscoveryItem('vsevex@example.com'),
        const SingleDiscoveryItem('vsevex@example.com', node: 'foo'),
        const SingleDiscoveryItem(
          'alyosha@example.com',
          node: 'bar',
          name: 'cart',
        ),
      };

      (iq['disco_items'] as DiscoItemsAbstract)['items'] = items;

      check(
        iq,
        '<iq><query xmlns="http://jabber.org/protocol/disco#items"><item jid="vsevex@example.com"/><item jid="vsevex@example.com" node="foo"/><item jid="alyosha@example.com" node="bar" name="cart"/></query></iq>',
        useValues: false,
      );
    });
  });
}
