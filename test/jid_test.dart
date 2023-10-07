import 'package:echox/src/jid/jid.dart';

import 'package:test/test.dart';

void main() {
  group('verify that the JabberID class can parse and manipulate JIDs', () {
    test('must properly check jid equality', () {
      final jid1 = JabberIDTemp(jid: 'user@domain/resource');
      final jid2 = JabberIDTemp(jid: 'user@domain/resource');

      expect(jid1, equals(jid2));
    });

    test('changing Jabber ID using aliases for domain', () {
      final jid = JabberIDTemp(jid: 'user@domain/resource');
      jid.server = 'anotherserver';
      expect(jid.domain, equals('anotherserver'));
      jid.host = 'anotherone';
      expect(jid.domain, equals('anotherone'));
    });

    test('setting the full Jaber ID with a user portion', () {
      final jid = JabberIDTemp(jid: 'user@domain/resource');
      jid.full = 'someotheruser@otherdomain/otherresource';
      expect(jid.node, equals('someotheruser'));
      expect(jid.domain, equals('otherdomain'));
      expect(jid.resource, equals('otherresource'));
      expect(jid.server, equals('otherdomain'));
      expect(jid.jid, equals('someotheruser@otherdomain/otherresource'));
    });

    test(
      'setting the full Jabber ID without a user portion and with a resource',
      () {
        final jid = JabberIDTemp(jid: 'user@domain/resource');
        jid.full = 'otherdomain/resource';
        expect(jid.node, isEmpty);
        expect(jid.domain, equals('otherdomain'));
        expect(jid.resource, equals('resource'));
        expect(jid.host, equals('otherdomain'));
      },
    );

    test(
      'setting the full Jabber ID without a user portion and without a resource',
      () {
        final jid = JabberIDTemp(jid: 'user@domain/resource');
        jid.full = 'otherdomain';
        expect(jid.node, isEmpty);
        expect(jid.domain, equals('otherdomain'));
        expect(jid.host, equals('otherdomain'));
        expect(jid.resource, isEmpty);
      },
    );

    test('setting the bare Jabber ID with a user', () {
      final jid = JabberIDTemp(jid: 'user@domain/resource');
      jid.bare = 'otheruser@otherdomain';
      expect(jid.node, equals('otheruser'));
      expect(jid.local, equals('otheruser'));
      expect(jid.domain, equals('otherdomain'));
      expect(jid.host, equals('otherdomain'));
      expect(jid.full, equals('otheruser@otherdomain/resource'));
    });

    test('setting the bare Jabber ID without a user', () {
      final jid = JabberIDTemp(jid: 'user@domain/resource');
      jid.bare = 'otherdomain';
      expect(jid.node, isEmpty);
      expect(jid.local, isEmpty);
      expect(jid.domain, 'otherdomain');
      expect(jid.host, equals('otherdomain'));
      expect(jid.resource, 'resource');
    });

    test('Jabber ID without a resource', () {
      final jid = JabberIDTemp(jid: 'user@someserver');
      expect(jid.node, equals('user'));
      expect(jid.local, equals('user'));
      expect(jid.domain, equals('someserver'));
      expect(jid.host, equals('someserver'));
      expect(jid.bare, equals('user@someserver'));
      expect(jid.resource, isEmpty);
    });
  });
}
