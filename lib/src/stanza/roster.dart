import 'package:dartz/dartz.dart';
import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/jid/jid.dart';
import 'package:echox/src/stream/base.dart';

import 'package:xml/xml.dart' as xml;

class Roster extends XMLBase {
  Roster()
      : super(
          name: 'query',
          namespace: Echotils.getNamespace('ROSTER'),
          pluginAttribute: 'roster',
          interfaces: {'items', 'ver'},
        ) {
    addSetters(<Symbol,
        void Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('ver'): (value, args, base) {
        if (value != null) {
          base.element!.setAttribute('ver', value as String);
        }
      },
      const Symbol('items'): (value, args, base) {
        delete('items');
        for (final jid in (value as Map).entries) {
          final item = RosterItem();
          item.values = value[jid.key] as Map<String, dynamic>;
          item['jid'] = jid.key;
          base.add(Tuple2(null, item));
        }
        return;
      },
    });

    addGetters(
      <Symbol, dynamic Function(dynamic args, XMLBase base)>{
        const Symbol('ver'): (args, base) => base.getAttribute('ver'),
        const Symbol('items'): (args, base) {
          final items = <String, Map<String, dynamic>>{};
          for (final item in base['substanzas'] as List) {
            if (item is RosterItem) {
              items[item['jid'] as String] = item.values;
            }
          }
          return items;
        },
      },
    );

    addDeleters(
      <Symbol, void Function(dynamic args, XMLBase base)>{
        const Symbol('items'): (args, base) {
          for (final item in base['substanzas'] as List) {
            if (item is RosterItem) {
              base.element!.children.remove(item.element);
            }
          }
        },
      },
    );
  }
}

class RosterItem extends XMLBase {
  RosterItem({super.includeNamespace = false})
      : super(
          name: 'item',
          namespace: Echotils.getNamespace('ROSTER'),
          pluginAttribute: 'item',
          interfaces: {
            'jid',
            'name',
            'subscription',
            'ask',
            'approved',
            'groups',
          },
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('jid'): (args, base) => base.getAttribute('jid'),
      const Symbol('groups'): (args, base) {
        final groups = <String>[];
        for (final group
            in base.element!.findAllElements('group', namespace: namespace)) {
          if (group.innerText.isNotEmpty) {
            groups.add(group.innerText);
          }
        }

        return groups;
      },
    });

    addSetters(<Symbol,
        void Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('jid'): (value, args, base) =>
          base.setAttribute('jid', JabberID(value as String).toString()),
      const Symbol('groups'): (value, args, base) {
        base.delete('groups');
        for (final groupName in value as List) {
          final group = Echotils.xmlElement('group');
          group.innerText = groupName as String;
          base.element!.children.add(group);
        }
      },
    });

    addDeleters(
      <Symbol, void Function(dynamic args, XMLBase base)>{
        const Symbol('groups'): (args, base) {
          for (final group
              in base.element!.findAllElements('group', namespace: namespace)) {
            base.element!.children.remove(group);
          }
          return;
        },
      },
    );
  }
}
