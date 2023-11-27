import 'package:dartz/dartz.dart';
import 'package:echox/src/stream/base.dart';

import 'package:test/test.dart';
import 'package:xml/xml.dart' as xml;

import 'class/base.dart';
import 'test_base.dart' as tester;

void main() {
  group('xml base test method and property test cases', () {
    test('extended name must return stanza correctly', () {
      final stanza = createTestStanza(name: 'foo/bar/baz', namespace: 'test');

      tester.check(stanza, '<foo xmlns="test"><bar><baz/></bar></foo>');
    });

    test('must extract languages after assigning to the stanza', () {
      final stanza = createTestStanza(
        name: 'lerko',
        namespace: 'test',
        interfaces: {'test'},
        subInterfaces: {'test'},
        languageInterfaces: {'test'},
      );

      final data = {
        'en': 'hi',
        'az': 'salam',
        'ru': 'blyat',
      };
      stanza['test|*'] = data;

      tester.check(
        stanza,
        '<lerko xmlns="test"><test xml:lang="en">hi</test><test xml:lang="az">salam</test><test xml:lang="ru">blyat</test></lerko>',
      );

      final getData = stanza['test|*'];

      expect(getData, equals(data));

      stanza.delete('test|*');
      tester.check(stanza, '<lerko xmlns="test"/>');
    });

    test(
      'deleting interfaces with no default language set must complete successfully',
      () {
        final stanza = createTestStanza(
          name: 'lerko',
          namespace: 'test',
          interfaces: {'test'},
          subInterfaces: {'test'},
          languageInterfaces: {'test'},
        );

        stanza['test'] = 'salam';
        stanza['test|no'] = 'hert';
        stanza['test|en'] = 'hi';

        tester.check(
          stanza,
          '<lerko xmlns="test"><test>salam</test><test xml:lang="no">cart</test><test xml:lang="en">hi</test></lerko>',
        );

        stanza.delete('test');
        tester.check(
          stanza,
          '<lerko xmlns="test"><test xml:lang="no">cart</test><test xml:lang="en">hi</test></lerko>',
        );
      },
    );

    test('interfaces must be deleted when a default language set', () {
      final stanza = createTestStanza(
        name: 'lerko',
        namespace: 'test',
        interfaces: const {'test'},
        subInterfaces: const {'test'},
        languageInterfaces: const {'test'},
      );

      stanza['lang'] = 'az';
      stanza['test'] = 'salam';
      stanza['test|no'] = 'cart';
      stanza['test|en'] = 'hi';

      tester.check(
        stanza,
        '<lerko xml:lang="az" xmlns="test"><test>salam</test><test xml:lang="no">cart</test><test xml:lang="en">hi</test></lerko>',
      );

      stanza.delete('test');
      tester.check(
        stanza,
        '<lerko xml:lang="az" xmlns="test"><test xml:lang="no">cart</test><test xml:lang="en">hi</test></lerko>',
      );

      stanza.delete('test|no');
      tester.check(
        stanza,
        '<lerko xml:lang="az" xmlns="test"><test xml:lang="en">hi</test></lerko>',
      );
    });

    test('must reset an interface when no default lang is used', () {
      final stanza = createTestStanza(
        name: 'lerko',
        namespace: 'test',
        interfaces: const {'test'},
        subInterfaces: const {'test'},
        languageInterfaces: const {'test'},
      );

      stanza['test'] = 'salam';
      stanza['test|en'] = 'hi';

      tester.check(
        stanza,
        '<lerko xmlns="test"><test>salam</test><test xml:lang="en">hi</test></lerko>',
      );

      stanza['test'] = 'cart';
      stanza['test|en'] = 'blya';

      tester.check(
        stanza,
        '<lerko xmlns="test"><test>cart</test><test xml:lang="en">blya</test></lerko>',
      );

      expect(stanza['test|en'], equals('blya'));
      expect(stanza['test'], equals('cart'));
    });

    test(
        'resetting an interface when a default language is used must work properly',
        () {
      final stanza = createTestStanza(
        name: 'lerko',
        namespace: 'test',
        interfaces: const {'test'},
        subInterfaces: const {'test'},
        languageInterfaces: const {'test'},
      );

      stanza['lang'] = 'az';
      stanza['test'] = 'salam';
      stanza['test|en'] = 'hi';

      tester.check(
        stanza,
        '<lerko xml:lang="az" xmlns="test"><test>salam</test><test xml:lang="en">hi</test></lerko>',
      );

      stanza['test|ru'] = 'blyat';
      tester.check(
        stanza,
        '<lerko xml:lang="az" xmlns="test"><test>salam</test><test xml:lang="en">hi</test><test xml:lang="ru">blyat</test></lerko>',
      );

      expect(stanza['test|ru'], equals('blyat'));
    });

    test('specifying various languages', () {
      final stanza = createTestStanza(
        name: 'lerko',
        namespace: 'test',
        interfaces: const {'test'},
        subInterfaces: const {'test'},
        languageInterfaces: const {'test'},
      );

      stanza['lang'] = 'az';
      stanza['test'] = 'salam';
      stanza['test|en'] = 'hi';

      tester.check(
        stanza,
        '<lerko xml:lang="az" xmlns="test"><test>salam</test><test xml:lang="en">hi</test></lerko>',
      );

      expect(stanza['test|az'], equals('salam'));
      expect(stanza['test|en'], equals('hi'));
    });

    test(
      'must finish the retrieval of the contents of a sub element successfully',
      () {
        final stanza = createTestStanza(
          name: 'blya',
          namespace: 'test',
          interfaces: const {'cart'},
          getters: {
            const Symbol('get_cart'): (args, base) =>
                base.getSubText('/wrapper/cart', def: 'zort'),
          },
          setters: {
            const Symbol('set_cart'): (value, args, base) {
              final wrapper = xml.XmlElement(xml.XmlName('wrapper'));
              final cart = xml.XmlElement(xml.XmlName('cart'));
              cart.innerText = value as String;
              wrapper.children.add(cart);
              base.element!.children.add(wrapper);
            },
          },
        );

        expect(stanza['cart'], equals('zort'));
        stanza['cart'] = 'hehe';
        tester.check(
          stanza,
          '<blya xmlns="test"><wrapper><cart>hehe</cart></wrapper></blya>',
        );
        expect(stanza['cart'], equals('hehe'));
      },
    );

    test('setting the contents of sub element must work properly', () {
      final stanza = createTestStanza(
        name: 'lerko',
        namespace: 'test',
        interfaces: {'hehe', 'boo'},
        getters: {
          const Symbol('get_hehe'): (args, base) =>
              base.getSubText('/wrapper/hehe'),
          const Symbol('get_boo'): (args, base) =>
              base.getSubText('/wrapper/boo'),
        },
        setters: {
          const Symbol('set_hehe'): (value, args, base) =>
              base.setSubText('/wrapper/hehe', text: value as String),
          const Symbol('set_boo'): (value, args, base) =>
              base.setSubText('/wrapper/boo', text: value as String),
        },
      );

      stanza['hehe'] = 'blya';
      stanza['boo'] = 'blya2';
      tester.check(
        stanza,
        '<lerko xmlns="test"><wrapper><hehe>blya</hehe><boo>blya2</boo></wrapper></lerko>',
      );
      stanza.setSubText('/wrapper/hehe', text: '', keep: true);
      tester.check(
        stanza,
        '<lerko xmlns="test"><wrapper><hehe/><boo>blya2</boo></wrapper></lerko>',
        useValues: false,
      );
      stanza['hehe'] = 'a';
      stanza.setSubText('/wrapper/hehe', text: '');
      tester.check(
        stanza,
        '<lerko xmlns="test"><wrapper><boo>blya2</boo></wrapper></lerko>',
      );
    });

    test('must return correct stanza after removal of substanzas', () {
      final stanza = createTestStanza(
        name: 'lerko',
        namespace: 'test',
        interfaces: {'hehe', 'boo'},
        setters: {
          const Symbol('set_hehe'): (value, args, base) => base
              .setSubText('/wrapper/herto/herto1/hehe', text: value as String),
          const Symbol('set_boo'): (value, args, base) => base
              .setSubText('/wrapper/herto/herto2/boo', text: value as String),
        },
        getters: {
          const Symbol('get_hehe'): (args, base) =>
              base.getSubText('/wrapper/herto/herto1/hehe'),
          const Symbol('get_boo'): (args, base) =>
              base.getSubText('/wrapper/herto/herto2/boo'),
        },
        deleters: {
          const Symbol('delete_hehe'): (args, base) =>
              base.deleteSub('/wrapper/herto/herto1/hehe'),
          const Symbol('delete_boo'): (args, base) =>
              base.deleteSub('/wrapper/herto/herto2/boo'),
        },
      );

      stanza['hehe'] = 'cart';
      stanza['boo'] = 'blya';
      tester.check(
        stanza,
        '<lerko xmlns="test"><wrapper><herto><herto1><hehe>cart</hehe></herto1><herto2><boo>blya</boo></herto2></herto></wrapper></lerko>',
      );
      stanza.delete('hehe');
      stanza.delete('boo');
      tester.check(
        stanza,
        '<lerko xmlns="test"><wrapper><herto><herto1/><herto2/></herto></wrapper></lerko>',
        useValues: false,
      );
      stanza['hehe'] = 'blyat';
      stanza['boo'] = 'zort';

      stanza.deleteSub('/wrapper/herto/herto1/hehe', all: true);
      tester.check(
        stanza,
        '<lerko xmlns="test"><wrapper><herto><herto2><boo>blya</boo></herto2></herto></wrapper></lerko>',
      );
    });

    test('must return false for non available property', () {
      final stanza = createTestStanza(
        name: 'foo',
        namespace: 'test',
        interfaces: {'bar'},
        boolInterfaces: {'bar'},
      );

      tester.check(stanza, '<foo xmlns="test"></foo>');

      expect(stanza['bar'], isFalse);

      stanza['bar'] = true;
      tester.check(stanza, '<foo xmlns="test"><bar/></foo>');

      stanza['bar'] = false;
      tester.check(stanza, '<foo xmlns="test"/>');
    });

    test('must override interfaces', () {
      final stanza = createTestStanza(
        name: 'foo',
        namespace: 'test',
        interfaces: {'bar', 'baz'},
      );
      final overriderStanza = createTestStanza(
        name: 'overrider',
        namespace: 'test',
        pluginAttribute: 'overrider',
        interfaces: {'bar'},
        overrides: ['set_bar'],
        includeNamespace: false,
        setters: {
          const Symbol('set_bar'): (value, args, base) {
            if (!(value as String).startsWith('override-')) {
              base.parent?.setAttribute('bar', 'override-$value');
            } else {
              base.parent?.setAttribute('bar', value);
            }
          },
        },
        setupOverride: (base, [element]) {
          base.element = xml.XmlElement(xml.XmlName(''));
        },
      );

      stanza['bar'] = 'foo';
      tester.check(stanza, '<foo bar="foo" xmlns="test"/>');

      registerStanzaPlugin(stanza, overriderStanza, overrides: true);
      stanza['bar'] = 'foo';
      tester.check(
        stanza,
        '<foo bar="override-foo" xmlns="test"><overrider/></foo>',
      );
    });

    test('XMLBase.isExtension property usage test', () {
      final extension = createTestStanza(
        name: 'extended',
        namespace: 'test',
        pluginAttribute: 'extended',
        interfaces: {'extended'},
        isExtension: true,
        includeNamespace: false,
        setters: {
          const Symbol('set_extended'): (value, args, base) =>
              base.element!.innerText = value as String,
        },
        getters: {
          const Symbol('get_extended'): (args, base) => base.element!.innerText,
        },
        deleters: {
          const Symbol('del_extended'): (args, base) =>
              base.parent!.element!.children.remove(base.element),
        },
      );
      final stanza = createTestStanza(
        name: 'foo',
        namespace: 'test',
        interfaces: {'bar', 'baz'},
      );

      registerStanzaPlugin(stanza, extension);
      stanza['extended'] = 'testing';
      tester.check(
        stanza,
        '<foo xmlns="test"><extended>testing</extended></foo>',
      );

      // expect(stanza['extended'], equals('testing'));
    });

    test('`values` getter test', () {
      final stanza = createTestStanza(
        name: 'foo',
        namespace: 'test',
        interfaces: {'bar', 'baz'},
      );
      final substanza = createTestStanza(
        name: 'subfoo',
        namespace: 'test',
        interfaces: {'bar', 'baz'},
      );
      final plugin = createTestStanza(
        name: 'foo2',
        namespace: 'test',
        interfaces: {'bar', 'baz'},
        pluginAttribute: 'foo2',
        includeNamespace: false,
      );

      registerStanzaPlugin(stanza, plugin, iterable: true);

      stanza['bar'] = 'a';
      (stanza['foo2'] as XMLBase)['baz'] = 'b';
      substanza['bar'] = 'c';
      stanza.add(Tuple2(null, substanza));

      expect(
        stanza.values,
        equals(
          {
            'lang': '',
            'bar': 'a',
            'baz': '',
            'foo2': {'lang': '', 'bar': '', 'baz': 'b'},
            'substanzas': [
              {
                'lang': '',
                'bar': '',
                'baz': 'b',
                '__childtag__': '<foo2 xmlns="test"/>',
              },
              {
                'lang': '',
                'bar': 'c',
                'baz': '',
                '__childtag__': '<subfoo xmlns="test"/>',
              }
            ],
          },
        ),
      );
    });

    test('accessing stanza interfaces', () {
      final stanza = createTestStanza(
        name: 'foo',
        namespace: 'test',
        interfaces: {'bar', 'baz', 'cart'},
        subInterfaces: {'bar'},
        getters: {const Symbol('get_cart'): (args, base) => 'cart'},
      );
      final plugin = createTestStanza(
        name: 'foobar',
        namespace: 'test',
        pluginAttribute: 'foobar',
        interfaces: {'xeem'},
        includeNamespace: false,
      );

      registerStanzaPlugin(stanza, stanza, iterable: true);
      registerStanzaPlugin(stanza, plugin);

      final substanza = stanza.copy();
      stanza.add(Tuple2(null, substanza));
      stanza.values = {
        'bar': 'a',
        'baz': 'b',
        'cart': 'gup',
        'foobar': {'xeem': 'c'},
      };

      final expected = {
        'substanzas': [substanza],
        'bar': 'a',
        'baz': 'b',
        'cart': 'cart',
      };

      for (final item in expected.entries) {
        final result = stanza[item.key];
        expect(result, equals(item.value));
      }

      expect((stanza['foobar'] as XMLBase)['xeem'], equals('c'));
    });

    test('`values` setter test', () {
      final stanza = createTestStanza(
        name: 'foo',
        namespace: 'test',
        interfaces: {'bar', 'baz'},
      );
      final substanza = createTestStanza(
        name: 'subfoo',
        namespace: 'test',
        interfaces: {'bar', 'baz'},
        includeNamespace: false,
      );
      final plugin = createTestStanza(
        name: 'pluginfoo',
        namespace: 'test',
        interfaces: {'bar', 'baz'},
        pluginAttribute: 'pluginfoo',
        includeNamespace: false,
      );

      registerStanzaPlugin(stanza, substanza, iterable: true);
      registerStanzaPlugin(stanza, plugin);
      const values = {
        'bar': 'a',
        'baz': '',
        'pluginfoo': {'bar': '', 'baz': 'b'},
        'substanzas': [
          {
            'bar': 'c',
            'baz': '',
            '__childtag__': '<subfoo xmlns="test"/>',
          }
        ],
      };
      stanza.values = values;
      tester.check(
        stanza,
        '<foo bar="a" xmlns="tes"><subfoo bar="c"/><pluginfoo baz="b"/></foo>',
      );
    });

    test(
      'retrieving multi_attribute substanzas using _Multi multifactory',
      () {
        final stanza = createTestStanza(name: 'foo', namespace: 'test');
        final multistanzaFirst = createTestStanza(
          name: 'bar',
          namespace: 'test',
          pluginAttribute: 'bar',
          pluginMultiAttribute: 'bars',
        );
        final multistanzaSecond = createTestStanza(
          name: 'baz',
          namespace: 'test',
          pluginAttribute: 'baz',
          pluginMultiAttribute: 'bazs',
        );

        registerStanzaPlugin(stanza, multistanzaFirst, iterable: true);
        registerStanzaPlugin(stanza, multistanzaSecond, iterable: true);

        stanza.add(Tuple2(null, multistanzaFirst));
        // stanza.add(Tuple2(null, GetMultiTestStanzaSecond()));
        // stanza.add(Tuple2(null, GetMultiTestStanzaFirst()));
        // stanza.add(Tuple2(null, GetMultiTestStanzaSecond()));

        print(stanza['bars']);
      },
    );

//     test('equality check', () {
//       final stanza = SimpleStanza();
//       stanza['hert'] = 'blya';

//       final stanza1 = SimpleStanza();
//       stanza1['cart'] = 'blya1';

//       stanza['cart'] = 'blya1';
//       stanza1['hert'] = 'blya';

//       final isEqual = stanza == stanza1;
//       expect(isEqual, isTrue);
//     });
  });
}
