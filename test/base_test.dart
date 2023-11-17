import 'package:dartz/dartz.dart';

import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/stream/base.dart';

import 'package:test/test.dart';
import 'package:xml/xml.dart' as xml;

import 'class/base.dart';
import 'test.dart' as tester;

void main() {
  group('fixNamespace method test cases', () {
    test(
      'fixing namespaces in an XPath expression must return correct match',
      () {
        final namespace = Echotils.getNamespace('DISCO_INFO');
        final result =
            fixNamespace('{$namespace}hert/lerko/{abc}cart/{$namespace}more');

        final expected = [
          '{$namespace}hert',
          '{$namespace}lerko',
          '{abc}cart',
          '{$namespace}more',
        ].join('/');

        expect(result.value1, equals(expected));
      },
    );
  });

  group('xml base test method and property test cases', () {
    test('extended name must return stanza correctly', () {
      final stanza = ExtendedNameTestStanza();

      tester.check(
        stanza,
        ExtendedNameTestStanza(
          xml.XmlDocument.parse(
            '<lerko xmlns="test"><hert><blya /></hert></lerko>',
          ).rootElement,
        ),
      );
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
