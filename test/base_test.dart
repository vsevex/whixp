import 'package:echox/src/stream/base.dart';
import 'package:test/test.dart';

import 'class/base.dart';
import 'test_base.dart' as tester;

void main() {
  group('xml base test method and property test cases', () {
    test('extended name must return stanza correctly', () {
      final stanza = ExtendedNameTestStanza();

      tester.check(
        stanza,
        ([element]) => ExtendedNameTestStanza(element: element),
        '<foo xmlns="test"><bar><baz/></bar></foo>',
      );
    });

    test('must extract languages after assigning to the stanza', () {
      final stanza = LanguageTestStanza();

      final data = {
        'en': 'hi',
        'az': 'salam',
        'ru': 'blyat',
      };
      stanza['test|*'] = data;

      tester.check(
        stanza,
        ([element]) => LanguageTestStanza(element: element),
        '<lerko xmlns="test"><test xml:lang="en">hi</test><test xml:lang="az">salam</test><test xml:lang="ru">blyat</test></lerko>',
      );

      final getData = stanza['test|*'];

      expect(getData, equals(data));

      stanza.delete('test|*');
      tester.check(
        stanza,
        ([element]) => LanguageTestStanza(element: element),
        '<lerko xmlns="test"/>',
      );
    });

    test(
      'deleting interfaces with no default language set must complete successfully',
      () {
        final stanza = LanguageTestStanza();

        stanza['test'] = 'salam';
        stanza['test|no'] = 'cart';
        stanza['test|en'] = 'hi';

        tester.check(
          stanza,
          ([element]) => LanguageTestStanza(element: element),
          '<lerko xmlns="test"><test>salam</test><test xml:lang="no">cart</test><test xml:lang="en">hi</test></lerko>',
        );

        stanza.delete('test');
        tester.check(
          stanza,
          ([element]) => LanguageTestStanza(element: element),
          '<lerko xmlns="test"><test xml:lang="no">cart</test><test xml:lang="en">hi</test></lerko>',
        );
      },
    );

    test('interfaces must be deleted when a default language set', () {
      final stanza = LanguageTestStanza();

      stanza['lang'] = 'az';
      stanza['test'] = 'salam';
      stanza['test|no'] = 'cart';
      stanza['test|en'] = 'hi';

      tester.check(
        stanza,
        ([element]) => LanguageTestStanza(element: element),
        '<lerko xml:lang="az" xmlns="test"><test>salam</test><test xml:lang="no">cart</test><test xml:lang="en">hi</test></lerko>',
      );

      stanza.delete('test');
      tester.check(
        stanza,
        ([element]) => LanguageTestStanza(element: element),
        '<lerko xml:lang="az" xmlns="test"><test xml:lang="no">cart</test><test xml:lang="en">hi</test></lerko>',
      );

      stanza.delete('test|no');
      tester.check(
        stanza,
        ([element]) => LanguageTestStanza(element: element),
        '<lerko xml:lang="az" xmlns="test"><test xml:lang="en">hi</test></lerko>',
      );
    });

    test('must reset an interface when no default lang is used', () {
      final stanza = LanguageTestStanza();

      stanza['test'] = 'salam';
      stanza['test|en'] = 'hi';

      tester.check(
        stanza,
        ([element]) => LanguageTestStanza(element: element),
        '<lerko xmlns="test"><test>salam</test><test xml:lang="en">hi</test></lerko>',
      );

      stanza['test'] = 'cart';
      stanza['test|en'] = 'blya';

      tester.check(
        stanza,
        ([element]) => LanguageTestStanza(element: element),
        '<lerko xmlns="test"><test>cart</test><test xml:lang="en">blya</test></lerko>',
      );

      expect(stanza['test|en'], equals('blya'));
      expect(stanza['test'], equals('cart'));
    });

    test(
        'resetting an interface when a default language is used must work properly',
        () {
      final stanza = LanguageTestStanza();

      stanza['lang'] = 'az';
      stanza['test'] = 'salam';
      stanza['test|en'] = 'hi';

      tester.check(
        stanza,
        ([element]) => LanguageTestStanza(element: element),
        '<lerko xml="az" xmlns="test"><test>salam</test><test xml:lang="en">hi</test></lerko>',
      );

      stanza['test|ru'] = 'blyat';
      tester.check(
        stanza,
        ([element]) => LanguageTestStanza(element: element),
        '<lerko xml="az" xmlns="test"><test>salam</test><test xml:lang="en">hi</test><test xml:lang="ru">blyat</test></lerko>',
      );

      expect(stanza['test|ru'], equals('blyat'));
    });

    test('specifying various languages', () {
      final stanza = LanguageTestStanza();

      stanza['lang'] = 'az';
      stanza['test'] = 'salam';
      stanza['test|en'] = 'hi';

      tester.check(
        stanza,
        ([element]) => LanguageTestStanza(element: element),
        '<lerko xml="az" xmlns="test"><test>salam</test><test xml:lang="en">hi</test></lerko>',
      );

      expect(stanza['test|az'], equals('salam'));
      expect(stanza['test|en'], equals('hi'));
    });

    test(
      'must finish the retrieval of the contents of a sub element successfully',
      () {
        final stanza = GetSubTextTestStanza();

        expect(stanza['cart'], equals('zort'));
        stanza['cart'] = 'hehe';
        tester.check(
          stanza,
          ([element]) => GetSubTextTestStanza(element: element),
          '<blya xmlns="test"><wrapper><cart>hehe</cart></wrapper></blya>',
        );
        expect(stanza['cart'], equals('hehe'));
      },
    );

    test('setting the contents of sub element must work properly', () {
      final stanza = SubElementTestStanza();
      stanza['hehe'] = 'blya';
      stanza['boo'] = 'blya2';
      tester.check(
        stanza,
        ([element]) => SubElementTestStanza(element: element),
        '<lerko xmlns="test"><wrapper><hehe>blya</hehe><boo>blya2</boo></wrapper></lerko>',
      );
      stanza.setSubText('/wrapper/hehe', text: '', keep: true);
      tester.check(
        stanza,
        ([element]) => SubElementTestStanza(element: element),
        '<lerko xmlns="test"><wrapper><hehe/><boo>blya2</boo></wrapper></lerko>',
      );
      stanza['hehe'] = 'a';
      stanza.setSubText('/wrapper/hehe', text: '');
      stanza.setSubText('/wrapper/boo', text: '');
      tester.check(
        stanza,
        ([element]) => SubElementTestStanza(element: element),
        '<lerko xmlns="test"><wrapper/></lerko>',
      );
    });

    test('must return correct stanza after removal of substanzas', () {
      final stanza = DeleteSubElementTestStanza();

      stanza['hehe'] = 'cart';
      stanza['boo'] = 'blya';
      tester.check(
        stanza,
        ([element]) => DeleteSubElementTestStanza(element: element),
        '<lerko xmlns="test"><wrapper><herto><herto1><hehe>cart</hehe></herto1><herto2><boo>blya</boo></herto2></herto></wrapper></lerko>',
      );
      stanza.delete('hehe');
      stanza.delete('boo');
      tester.check(
        stanza,
        ([element]) => DeleteSubElementTestStanza(element: element),
        '<lerko xmlns="test"><wrapper><herto><herto1/><herto2/></herto></wrapper></lerko>',
      );
      stanza['hehe'] = 'blyat';
      stanza['boo'] = 'zort';

      stanza.deleteSub('/wrapper/herto/herto1/hehe');
      tester.check(
        stanza,
        ([element]) => DeleteSubElementTestStanza(element: element),
        '<lerko xmlns="test"><wrapper><herto><herto1/><herto2><boo>blya</boo></herto2></herto></wrapper></lerko>',
      );
    });

    test('must return false for non available property', () {
      final stanza = BooleanInterfaceStanza();

      tester.check(
        stanza,
        ([element]) => BooleanInterfaceStanza(element: element),
        '<foo xmlns="test"></foo>',
      );

      expect(stanza['bar'], isFalse);

      stanza['bar'] = true;
      tester.check(
        stanza,
        ([element]) => BooleanInterfaceStanza(element: element),
        '<foo xmlns="test"><bar/></foo>',
      );
    });

    test('must override interfaces', () {
      final overriderStanza = OverriderStanza();
      XMLBase stanza = OverridedStanza();

      stanza['bar'] = 'foo';
      tester.check(
        stanza,
        ([element]) => OverridedStanza(element: element),
        '<foo bar="foo" xmlns="test"/>',
      );

      registerStanzaPlugin(stanza, overriderStanza, overrides: true);
      stanza = OverridedStanza();
      stanza['bar'] = 'foo';
      print(stanza);
    });

    test('equality check', () {
      final stanza = SimpleStanza();
      stanza['hert'] = 'blya';

      final stanza1 = SimpleStanza();
      stanza1['cart'] = 'blya1';

      stanza['cart'] = 'blya1';
      stanza1['hert'] = 'blya';

      final isEqual = stanza == stanza1;
      expect(isEqual, isTrue);
    });
  });
}
