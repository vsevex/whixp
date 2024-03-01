import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// ### Example:
/// ```xml
///  <iq type="set">
///   <query xmlns="jabber:iq:roster">
///     <item jid="vsevex@example.com" subscription="both" name="Vsevolod">
///       <group>hokkabazlar</group>
///     </item>
///   </query>
/// </iq>
/// ```
class Roster extends XMLBase {
  /// The [Roster] class provides functionality for handling XMPP roster-related
  /// queries.
  ///
  /// ### Example:
  /// ```dart
  /// final iq = IQ();
  /// final roster = Roster();
  /// iq.registerPlugin(roster);
  /// (iq['roster'] as XMLBase)['items'] = {
  ///   'vsevex@example.com': {
  ///     'name': 'Vsevolod',
  ///     'subscription': 'both',
  ///     'groups': ['cart', 'hella'],
  ///   },
  ///   'alyosha@example.com': {
  ///    'name': 'Alyosha',
  ///    'subscription': 'both',
  ///    'groups': ['gup'],
  ///   },
  /// }; /// ...sets items of the [Roster] stanza in the IQ stanza
  /// ```
  Roster({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.pluginIterables,
    super.getters,
    super.setters,
    super.deleters,
    super.element,
    super.parent,
  }) : super(
          name: 'query',
          namespace: WhixpUtils.getNamespace('ROSTER'),
          pluginAttribute: 'roster',
          interfaces: {'items', 'ver'},
        ) {
    addGetters(
      <Symbol, dynamic Function(dynamic args, XMLBase base)>{
        const Symbol('ver'): (args, base) => base.getAttribute('ver'),
        const Symbol('items'): (args, base) {
          final items = <String, Map<String, dynamic>>{};
          for (final item in base['substanzas'] as List<XMLBase>) {
            if (item is RosterItem) {
              items[item['jid'] as String] = item.values;
            }
          }
          return items;
        },
      },
    );

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
          base.add(item);
        }
        return;
      },
    });

    addDeleters(
      <Symbol, void Function(dynamic args, XMLBase base)>{
        const Symbol('items'): (args, base) {
          for (final item in base['substanzas'] as List<XMLBase>) {
            if (item is RosterItem) {
              base.element!.children.remove(item.element);
            }
          }
        },
      },
    );

    registerPlugin(RosterItem(), iterable: true);
  }

  @override
  Roster copy({xml.XmlElement? element, XMLBase? parent}) => Roster(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        pluginIterables: pluginIterables,
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}

/// Represents an individual roster item within the roster query.
class RosterItem extends XMLBase {
  /// ### Example:
  /// ```dart
  /// final roster = Roster();
  /// final item = RosterItem();
  /// roster.registerPlugin(item);
  /// ```
  RosterItem({
    super.getters,
    super.setters,
    super.deleters,
    super.element,
    super.parent,
  }) : super(
          name: 'item',
          namespace: WhixpUtils.getNamespace('ROSTER'),
          includeNamespace: false,
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
        for (final group in base.element!.findAllElements('group')) {
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
          final group = WhixpUtils.xmlElement('group');
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

  @override
  RosterItem copy({xml.XmlElement? element, XMLBase? parent}) => RosterItem(
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}
