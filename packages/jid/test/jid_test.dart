import 'package:jid/jid.dart';

import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

void main() {
  late JabberID jid;

  setUp(() => jid = JabberID('example', domain: 'localhost'));

  group('set methods test', () {
    test('sets local with escaping when escape is true', () {
      jid.setLocal('lerko blya');
      expect(jid.local, equals('lerko\\20blya'));
    });

    test('sets local without escaping', () {
      jid.setLocal('lerkoblya');
      expect(jid.local, equals('lerkoblya'));
    });

    test('must set all chars of domain lowercase', () {
      jid.setDomain('LOCALHOST');
      expect(jid.domain, 'localhost');
    });
  });

  test('fromString factory method test', () {
    final jid = JabberID.fromString('hert@localhost/mobile');

    expect(jid.local, equals('hert'));
    expect(jid.domain, equals('localhost'));
    expect(jid.resource, equals('mobile'));
  });

  group('toString method test', () {
    test(
      'must return the basic string representation',
      () {
        final jid = JabberID('hert', domain: 'localhost', resource: 'mobile');
        expect(jid.toString(), equals('hert@localhost/mobile'));
      },
    );

    test('must return the string representation with unescaped local', () {
      final jid = JabberID('hert blya', domain: 'localhost');
      expect(jid.toString(unescape: true), equals('hert blya@localhost'));
    });

    test(
      'must return the string representation with escaped local and resource',
      () {
        final jid =
            JabberID('lerko blya', domain: 'localhost', resource: 'desktop');
        expect(jid.toString(), equals('lerko\\20blya@localhost/desktop'));
      },
    );
  });

  test('bare getter test', () {
    final jid = JabberID('hert', domain: 'localhost', resource: 'mobile');
    expect(jid.bare.toString(), 'hert@localhost');
  });
}
