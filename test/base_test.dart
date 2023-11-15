import 'package:dartz/dartz.dart';
import 'package:echox/src/stream/base.dart';

import 'package:test/scaffolding.dart';
import 'package:test/test.dart';

import 'class/base.dart';

void main() {
  group('multi private class test cases', () {
    test('must return correct substanzas on getMulti call', () {
      registerStanzaPlugin(TestStanza(), TestMultiStanza1(), iterable: true);
      registerStanzaPlugin(TestStanza(), TestMultiStanza2(), iterable: true);

      final stanza = TestStanza();
      stanza.add(Tuple2(null, TestMultiStanza1()));
      stanza.add(Tuple2(null, TestMultiStanza2()));
      stanza.add(Tuple2(null, TestMultiStanza1()));
      stanza.add(Tuple2(null, TestMultiStanza2()));

      print(stanza['bars']);
    });
  });
}
