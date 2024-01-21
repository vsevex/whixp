import 'package:dartz/dartz.dart';

import 'package:test/test.dart';

import 'package:whixp/src/stream/base.dart';

import 'package:xml/xml.dart' as xml;

import 'class/base.dart';
import 'test_base.dart' as tester;

void main() {
  group('fix namespace test caases', () {
    test('fixing namespaces in an XPath expression', () {
      const namespace = 'http://jabber.org/protocol/disco#items';
      const result = '{$namespace}test/bar/{abc}baz';

      expect(
        fixNamespace(result),
        equals(
          const Tuple2(
            '<test xmlns="http://jabber.org/protocol/disco#items"/>/<bar xmlns="http://jabber.org/protocol/disco#items"/>/<baz xmlns="abc"/>',
            null,
          ),
        ),
      );
    });
  });
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
            const Symbol('cart'): (args, base) =>
                base.getSubText('/wrapper/cart', def: 'zort'),
          },
          setters: {
            const Symbol('cart'): (value, args, base) {
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
          const Symbol('hehe'): (args, base) =>
              base.getSubText('/wrapper/hehe'),
          const Symbol('boo'): (args, base) => base.getSubText('/wrapper/boo'),
        },
        setters: {
          const Symbol('hehe'): (value, args, base) =>
              base.setSubText('/wrapper/hehe', text: value as String),
          const Symbol('boo'): (value, args, base) =>
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
          const Symbol('hehe'): (value, args, base) => base
              .setSubText('/wrapper/herto/herto1/hehe', text: value as String),
          const Symbol('boo'): (value, args, base) => base
              .setSubText('/wrapper/herto/herto2/boo', text: value as String),
        },
        getters: {
          const Symbol('hehe'): (args, base) =>
              base.getSubText('/wrapper/herto/herto1/hehe'),
          const Symbol('boo'): (args, base) =>
              base.getSubText('/wrapper/herto/herto2/boo'),
        },
        deleters: {
          const Symbol('hehe'): (args, base) =>
              base.deleteSub('/wrapper/herto/herto1/hehe'),
          const Symbol('boo'): (args, base) =>
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
      );

      stanza['bar'] = 'foo';
      tester.check(stanza, '<foo bar="foo" xmlns="test"/>');

      registerStanzaPlugin(stanza, overriderStanza, overrides: true);
      stanza['bar'] = 'foo';
      tester.check(
        stanza,
        '<foo bar="override-foo" xmlns="test"></foo>',
      );
    });

    test('XMLBase.isExtension property usage test', () {
      final extension = createTestStanza(
        name: 'extended',
        namespace: 'test',
        pluginAttribute: 'extended',
        interfaces: {'extended'},
        includeNamespace: false,
        isExtension: true,
        setters: {
          const Symbol('extended'): (value, args, base) =>
              base.element!.innerText = value as String,
        },
        getters: {
          const Symbol('extended'): (args, base) => base.element!.innerText,
        },
        deleters: {
          const Symbol('extended'): (args, base) =>
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
      stanza.add(substanza);

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
                '__childtag__': '{test}foo2',
              },
              {
                'lang': '',
                'bar': 'c',
                'baz': '',
                '__childtag__': '{test}subfoo',
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
        getters: {const Symbol('cart'): (args, base) => 'cart'},
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
      stanza.add(substanza);
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
            '__childtag__': '{test}subfoo',
          }
        ],
      };
      stanza.values = values;
      tester.check(
        stanza,
        '<foo bar="a" xmlns="test"><subfoo bar="c"/><pluginfoo baz="b"/></foo>',
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
        final multistanzaSecond = MultiTestStanza2(
          name: 'baz',
          namespace: 'test',
          pluginAttribute: 'baz',
          pluginMultiAttribute: 'bazs',
        );
        final multistanzaThird = createTestStanza(
          name: 'bar',
          namespace: 'test',
          pluginAttribute: 'bar',
          pluginMultiAttribute: 'bars',
        );
        final multistanzaFourth = MultiTestStanza2(
          name: 'baz',
          namespace: 'test',
          pluginAttribute: 'baz',
          pluginMultiAttribute: 'bazs',
        );

        registerStanzaPlugin(stanza, multistanzaFirst, iterable: true);
        registerStanzaPlugin(stanza, multistanzaSecond, iterable: true);

        stanza.add(multistanzaFirst);
        stanza.add(multistanzaSecond);
        stanza.add(multistanzaThird);
        stanza.add(multistanzaFourth);

        tester.check(
          stanza,
          '<foo xmlns="foo"><bar xmlns="bar"/><baz xmlns="baz"/><bar xmlns="bar"/><baz xmlns="baz"/></foo>',
          useValues: false,
        );

        final bars = stanza['bars'];
        final bazs = stanza['bazs'];

        for (final bar in bars as List<XMLBase>) {
          tester.check(bar, '<bar xmlns="bar"/>');
        }

        for (final baz in bazs as List<XMLBase>) {
          tester.check(baz, '<baz xmlns="baz"/>');
        }

        expect(bars.length, equals(2));
        expect(bazs.length, equals(2));
      },
    );

    test(
      'test setting multi_attribute substanzas',
      () {
        final stanza = createTestStanza(name: 'foo', namespace: 'test');
        final multistanzaFirst = createTestStanza(
          name: 'bar',
          namespace: 'test',
          pluginAttribute: 'bar',
          pluginMultiAttribute: 'bars',
        );
        final multistanzaSecond = MultiTestStanza2(
          name: 'baz',
          namespace: 'test',
          pluginAttribute: 'baz',
          pluginMultiAttribute: 'bazs',
        );
        final multistanzaThird = createTestStanza(
          name: 'bar',
          namespace: 'test',
          pluginAttribute: 'bar',
          pluginMultiAttribute: 'bars',
        );
        final multistanzaFourth = MultiTestStanza2(
          name: 'baz',
          namespace: 'test',
          pluginAttribute: 'baz',
          pluginMultiAttribute: 'bazs',
        );

        registerStanzaPlugin(stanza, multistanzaFirst, iterable: true);
        registerStanzaPlugin(stanza, multistanzaSecond, iterable: true);

        stanza['bars'] = [multistanzaFirst, multistanzaThird];
        stanza['bazs'] = [multistanzaSecond, multistanzaFourth];

        tester.check(
          stanza,
          '<foo xmlns="test"><bar xmlns="test"/><bar xmlns="test"/><baz xmlns="test"/><baz xmlns="test"/></foo>',
          useValues: false,
        );

        expect((stanza['substanzas'] as List<XMLBase>).length, equals(4));

        stanza['bars'] = [multistanzaFirst];

        tester.check(
          stanza,
          '<foo xmlns="test"><baz xmlns="test"/><baz xmlns="test"/><bar xmlns="test"/></foo>',
          useValues: false,
        );

        expect((stanza['substanzas'] as List<XMLBase>).length, equals(3));
      },
    );

    test(
      'must delete multi_attribute substanzas properly',
      () {
        final stanza = createTestStanza(name: 'foo', namespace: 'test');
        final multistanzaFirst = createTestStanza(
          name: 'bar',
          namespace: 'test',
          pluginAttribute: 'bar',
          pluginMultiAttribute: 'bars',
        );
        final multistanzaSecond = MultiTestStanza2(
          name: 'baz',
          namespace: 'test',
          pluginAttribute: 'baz',
          pluginMultiAttribute: 'bazs',
        );
        final multistanzaThird = createTestStanza(
          name: 'bar',
          namespace: 'test',
          pluginAttribute: 'bar',
          pluginMultiAttribute: 'bars',
        );
        final multistanzaFourth = MultiTestStanza2(
          name: 'baz',
          namespace: 'test',
          pluginAttribute: 'baz',
          pluginMultiAttribute: 'bazs',
        );

        registerStanzaPlugin(stanza, multistanzaFirst, iterable: true);
        registerStanzaPlugin(stanza, multistanzaSecond, iterable: true);

        stanza['bars'] = [multistanzaFirst, multistanzaThird];
        stanza['bazs'] = [multistanzaSecond, multistanzaFourth];

        tester.check(
          stanza,
          '<foo xmlns="test"><bar xmlns="test"/><bar xmlns="test"/><baz xmlns="test"/><baz xmlns="test"/></foo>',
          useValues: false,
        );

        expect((stanza['substanzas'] as List<XMLBase>).length, equals(4));

        stanza.delete('bars');

        tester.check(
          stanza,
          '<foo xmlns="test"><baz xmlns="test"/><baz xmlns="test"/></foo>',
          useValues: false,
        );

        expect((stanza['substanzas'] as List<XMLBase>).length, equals(2));
      },
    );
  });
}
