import 'package:test/test.dart';

import 'package:whixp/whixp.dart';

import 'test_base.dart';

void main() {
  late IQ iq;

  setUp(() => iq = IQ(generateID: false)..enable('command'));

  group('command stanza from Ad-Hoc test cases', () {
    test('using action attribute', () {
      iq['type'] = 'set';
      final command = iq['command'] as Command;
      command['node'] = 'cart';

      command['action'] = 'execute';
      expect(command['action'], equals('execute'));
      expect(command.action, equals('execute'));

      command['action'] = 'complete';
      expect(command['action'], equals('complete'));
      expect(command.action, equals('complete'));

      command['action'] = 'cancel';
      expect(command['action'], equals('cancel'));
      expect(command.action, equals('cancel'));
    });

    test('setting next action in a command stanza', () {
      final command = iq['command'] as Command;
      iq['type'] = 'result';
      command['node'] = 'cart';
      command['actions'] = ['prev', 'next'];

      check(
        iq,
        '<iq type="result"><command xmlns="http://jabber.org/protocol/commands" node="cart"><actions><prev/><next/></actions></command></iq>',
      );
    });

    test('must properly retrieve next actions from a command stanza', () {
      final command = iq['command'] as Command;
      command['node'] = 'cart';
      command['actions'] = ['prev', 'next'];

      final results = command['actions'];
      final expected = ['prev', 'next'];
      expect(results, equals(expected));
    });

    test('must properly delete all actions from command stanza', () {
      final command = iq['command'] as Command;
      iq['type'] = 'result';
      command['node'] = 'cart';
      command['actions'] = ['prev', 'next'];

      /// or `command.deleteActions()`
      command.delete('actions');
      check(
        iq,
        '<iq type="result"><command xmlns="http://jabber.org/protocol/commands" node="cart"/></iq>',
      );
    });

    test('adding a command note', () {
      final command = iq['command'] as Command;
      iq['type'] = 'result';
      command['node'] = 'cart';
      command.addNote('something happened, blyat!', 'warning');

      check(
        iq,
        '<iq type="result"><command xmlns="http://jabber.org/protocol/commands" node="cart"><note type="warning">Something happened, blyat!</note></command></iq>',
      );
    });

    test('command notes test case', () {
      final command = iq['command'] as Command;
      iq['type'] = 'result';
      command['node'] = 'cart';

      final notes = <String, String>{
        'info': 'xeeem',
        'warning': 'gup',
        'error': 'some error happened',
      };

      command['notes'] = notes;

      expect(command['notes'], equals(notes));

      check(
        iq,
        '<iq type="result"><command xmlns="http://jabber.org/protocol/commands" node="cart"><note type="info">xeeem</note><note type="warning">gup</note><note type="error">some error happened</note></command></iq>',
      );
    });
  });
}
