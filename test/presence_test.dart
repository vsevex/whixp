import 'package:test/test.dart';

import 'package:whixp/src/stanza/presence.dart';

import 'test_base.dart';

void main() {
  group('Presence stanza test cases', () {
    test('regression check presence["type"] = "dnd" show value working', () {
      final presence = Presence();
      presence['type'] = 'dnd';
      check(presence, '<presence><show>dnd</show></presence>');
    });

    test('properly manipulate presence type', () {
      final presence = Presence();
      presence['type'] = 'available';
      check(presence, '<presence/>');
      expect(presence['type'], 'available');

      for (final showtype in {'away', 'chat', 'dnd', 'xa'}) {
        presence['type'] = showtype;
        check(presence, '<presence><show>$showtype</show></presence>');
        expect(presence['type'], showtype);
      }

      presence.delete('type');
      check(presence, '<presence/>');
    });
  });
}
