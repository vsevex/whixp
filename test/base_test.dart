import 'package:dartz/dartz.dart';
import 'package:echox/src/stream/base.dart';

import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

import 'class/base.dart';

void main() {
  group('multi private class test cases', () {
    test('must set a normal subinterface when a default language is set', () {
      final stanza = DefaultLanguageTestStanza();

      stanza['lang'] = 'sv';
      stanza['test'] = 'hej';
    });
  });
}
