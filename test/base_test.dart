import 'package:dartz/dartz.dart';
import 'package:test/test.dart';

import 'class/base.dart';
import 'test_base.dart' as tester;

void main() {
  group('xml base test method and property test cases', () {
    test('extended name must return stanza correctly', () {
      final stanza = ExtendedNameTestStanza();

      tester.check(
        stanza,
        (element) => ExtendedNameTestStanza(element: element),
        '<foo xmlns="test"><bar><baz /></bar></foo>',
      );
    });

    test(
      'must finish the retrieval of the contents of a sub element successfully',
      () {
        final stanza = GetSubTextTestStanza();

        expect((stanza['cart'] as Tuple2).value1, equals('zort'));
        stanza['cart'] = 'hehe';
        tester.check(
          stanza,
          (element) => GetSubTextTestStanza(element: element),
          '<blya xmlns="test"><wrapper><cart>hehe</cart></wrapper></blya>',
        );
        expect(stanza['cart'], equals(const Tuple2('hehe', null)));
      },
    );

    test('setting the contents of sub element must work properly', () {
      final stanza = SubElementTestStanza();
      stanza['hehe'] = 'blya';
      stanza['boo'] = 'blya2';
      tester.check(
        stanza,
        (element) => SubElementTestStanza(element: element),
        '<lerko xmlns="test"><wrapper><hehe>blya</hehe><boo>blya2</boo></wrapper></lerko>',
      );
      stanza.setSubText('/wrapper/hehe', text: '', keep: true);
      tester.check(
        stanza,
        (element) => SubElementTestStanza(element: element),
        '<lerko xmlns="test"><wrapper><hehe/><boo>blya2</boo></wrapper></lerko>',
      );
      stanza['hehe'] = 'a';
      stanza.setSubText('/wrapper/hehe', text: '');
      stanza.setSubText('/wrapper/boo', text: '');
      tester.check(
        stanza,
        (element) => SubElementTestStanza(element: element),
        '<lerko xmlns="test"><wrapper/></lerko>',
      );
    });

    test('must return correct stanza after removal of substanzas', () {
      final stanza = DeleteSubElementTestStanza();

      stanza['hehe'] = 'cart';
      stanza['boo'] = 'blya';
      tester.check(
        stanza,
        (element) => DeleteSubElementTestStanza(element: element),
        '<lerko xmlns="test"><wrapper><herto><herto1><hehe>cart</hehe></herto1><herto2><boo>blya></boo></herto2></herto></wrapper></lerko>',
      );
      stanza.delete('hehe');
      stanza.delete('boo');
      tester.check(
        stanza,
        (element) => DeleteSubElementTestStanza(element: element),
        '<lerko xmlns="test"><wrapper><herto><herto1/><herto2/></herto></wrapper></lerko>',
      );
      stanza['hehe'] = 'blyat';
      stanza['boo'] = 'zort';

      stanza.deleteSub('/wrapper/herto/herto1/hehe');
      tester.check(
        stanza,
        (element) => DeleteSubElementTestStanza(element: element),
        '<lerko xmlns="test"><wrapper><herto><herto1/><herto2><boo>blya></boo></herto2></herto></wrapper></lerko>',
      );
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

  group('multi private class test cases', () {
    test('must set a normal subinterface when a default language is set', () {
      final stanza = DefaultLanguageTestStanza();

      stanza['lang'] = 'sv';
      stanza['test'] = 'blya';

      // expect(stanza['test|sv'], equals(const Tuple2('blya', null)));
      // expect(stanza['test'], equals(const Tuple2('blya', null)));
      // expect(stanza['lang'], equals('sv'));
    });
  });
}
