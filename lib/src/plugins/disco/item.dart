part of 'disco.dart';

class DiscoItem extends XMLBase {
  DiscoItem({super.includeNamespace = false, super.element, super.parent})
      : super(
          name: 'item',
          namespace: WhixpUtils.getNamespace('DISCO_ITEMS'),
          pluginAttribute: 'item',
          interfaces: {'jid', 'node', 'name'},
          getters: <Symbol, dynamic Function(dynamic args, XMLBase base)>{
            const Symbol('node'): (args, base) => base.getAttribute('node'),
            const Symbol('name'): (args, base) => base.getAttribute('name'),
          },
        );

  @override
  DiscoItem copy({xml.XmlElement? element, XMLBase? parent}) => DiscoItem(
        includeNamespace: includeNamespace,
        element: element,
        parent: parent,
      );
}

/// Represents an item used in the context of discovery. It is designed to hold
/// information related to a discovery item, including a [jid] in a [String]
/// format, [node], and a [name].
class SingleDiscoveryItem {
  /// Constructs an item with the provided [name], [node], and [name].
  const SingleDiscoveryItem(this.jid, {this.node, this.name});

  /// The Jabber identifier with the discovery item.
  final String jid;

  /// The node information associated with the discovery item.
  final String? node;

  /// The name associated with the discovery item.
  final String? name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SingleDiscoveryItem &&
          runtimeType == other.runtimeType &&
          jid == other.jid &&
          node == other.node &&
          name == other.name;

  @override
  int get hashCode => jid.hashCode ^ node.hashCode ^ name.hashCode;

  @override
  String toString() =>
      'Service Discovery Item (jid: $jid, node: $node, name: $name)';
}

class DiscoveryItems extends XMLBase {
  DiscoveryItems({
    super.pluginAttributeMapping,
    super.pluginTagMapping,
    super.pluginIterables,
    super.getters,
    super.deleters,
    super.element,
    super.parent,
  }) : super(
          name: 'query',
          namespace: WhixpUtils.getNamespace('DISCO_ITEMS'),
          includeNamespace: true,
          pluginAttribute: 'disco_items',
          interfaces: {'node', 'items'},
        ) {
    addGetters(
      <Symbol, dynamic Function(dynamic args, XMLBase base)>{
        /// Returns all items.
        const Symbol('items'): (args, base) => items,
      },
    );

    addSetters(
      <Symbol, void Function(dynamic value, dynamic args, XMLBase base)>{
        const Symbol('items'): (value, args, base) =>
            setItems(value as Set<SingleDiscoveryItem>),
      },
    );

    addDeleters(
      <Symbol, dynamic Function(dynamic args, XMLBase base)>{
        /// Returns all items.
        const Symbol('items'): (args, base) => removeItems(),
      },
    );

    registerPlugin(DiscoItem(), iterable: true);
    registerPlugin(RSMStanza());
  }

  final _items = <Tuple2<String, String?>>{};

  /// Returns all items.
  Set<SingleDiscoveryItem> get items {
    final items = <SingleDiscoveryItem>{};
    for (final item in this['substanzas'] as List<XMLBase>) {
      if (item is DiscoItem) {
        items.add(
          SingleDiscoveryItem(
            item['jid'] as String,
            node: item['node'] as String?,
            name: item['name'] as String?,
          ),
        );
      }
    }
    return items;
  }

  /// Removes all items.
  void removeItems() {
    final items = <DiscoItem>{};
    for (final item in iterables) {
      if (item is DiscoItem) {
        items.add(item);
      }
    }

    for (final item in items) {
      element!.children.remove(item.element);
      iterables.remove(item);
    }
  }

  /// Sets or replaces all items. The given [items] ust in a [Set] where each
  /// item is a [DiscoveryItem] form.
  void setItems(Set<SingleDiscoveryItem> items) {
    removeItems();
    for (final item in items) {
      addItem(item.jid, node: item.node, name: item.name);
    }
  }

  /// Adds a new item element. Each item is required to have Jabber ID, but may
  /// also specify a [node] value to reference non-addressable entities.
  bool addItem(String jid, {String? node, String? name}) {
    if (!_items.contains(Tuple2(jid, node))) {
      _items.add(Tuple2(jid, node));
      final item = DiscoItem(parent: this);
      item['jid'] = jid;
      item['node'] = node;
      item['name'] = name;
      iterables.add(item);
      return true;
    }
    return false;
  }

  /// Removes a single item.
  bool removeItem(String jid, {String? node}) {
    if (_items.contains(Tuple2(jid, node))) {
      for (final itemElement
          in element!.findAllElements('item', namespace: namespace)) {
        final item = Tuple2(
          itemElement.getAttribute('jid'),
          itemElement.getAttribute('node'),
        );
        if (item == Tuple2(jid, node)) {
          element!.children.remove(itemElement);
          return true;
        }
      }
    }

    return false;
  }

  @override
  DiscoveryItems copy({xml.XmlElement? element, XMLBase? parent}) =>
      DiscoveryItems(
        pluginAttributeMapping: pluginAttributeMapping,
        pluginTagMapping: pluginTagMapping,
        pluginIterables: pluginIterables,
        getters: getters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}
