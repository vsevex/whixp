part of 'pubsub.dart';

final _namespace = WhixpUtils.getNamespace('PUBSUB');
final _ownerNamespace = '$_namespace#owner';
final _eventNamespace = '$_namespace#event';

class PubSubStanza extends MessageStanza implements IQStanza {
  PubSubStanza({
    this.publish,
    this.retract,
    this.owner = false,
    List<Node>? nodes,
    Map<String, List<_Item>>? items,
    this.configuration,
  }) {
    this.nodes = nodes ?? <Node>[];
    this.items = items ?? <String, List<_Item>>{};
  }

  final _Publish? publish;
  final _Retract? retract;
  final Node? configuration;
  final bool owner;
  late Map<String, List<_Item>> items;
  late List<Node> nodes;

  factory PubSubStanza.fromXML(xml.XmlElement node) {
    _Publish? publish;
    _Retract? retract;
    Node? configuration;
    final nodes = <Node>[];
    final items = <String, List<_Item>>{};

    for (final child in node.children.whereType<xml.XmlElement>()) {
      switch (child.localName) {
        case 'publish':
          publish = _Publish.fromXML(child);
        case 'retract':
          retract = _Retract.fromXML(child);
        case 'configuration':
          configuration = Node.fromXML(child);
        case 'default':
          configuration = Node.fromXML(child);
        case 'items':
          for (final item in child.children.whereType<xml.XmlElement>()) {
            if (child.getAttribute('node') != null) {
              if (items[child.getAttribute('node')] == null) {
                items[child.getAttribute('node')!] = <_Item>[];
              }
            }
            items[child.getAttribute('node') ?? '']?.add(_Item.fromXML(item));
          }
        default:
          nodes.add(Node.fromXML(child));
      }
    }

    return PubSubStanza(
      publish: publish,
      configuration: configuration,
      items: items,
      retract: retract,
      nodes: nodes,
    );
  }

  @override
  xml.XmlElement toXML() {
    final element = WhixpUtils.xmlElement(
      name,
      namespace: owner ? _ownerNamespace : _namespace,
    );

    if (publish != null) {
      element.children.add(publish!.toXML().copy());
    }
    if (retract != null) {
      element.children.add(retract!.toXML().copy());
    }
    if (configuration != null) {
      element.children.add(configuration!.toXML().copy());
    }
    if (nodes.isNotEmpty) {
      for (final node in nodes) {
        element.children.add(node.toXML().copy());
      }
    }

    return element;
  }

  /// Adds the passed [node] to the nodes list.
  void addNode(Node node) => nodes.add(node);

  @override
  String get name => 'pubsub';

  @override
  String get namespace => _namespace;

  @override
  String get tag => pubsubTag;
}

class PubSubEvent extends MessageStanza {
  const PubSubEvent({this.payloads, this.items, this.retractItems});

  final List<Node>? payloads;
  final Map<String, List<_Item>>? items;
  final Map<String, List<_Retract>>? retractItems;

  factory PubSubEvent.fromXML(xml.XmlElement node) {
    final payloads = <Node>[];
    final items = <String, List<_Item>>{};
    final retracts = <String, List<_Retract>>{};

    for (final child in node.children.whereType<xml.XmlElement>()) {
      if (child.localName == 'delete') {
        payloads.add(Node.fromXML(child));
      }
      if (child.localName == 'items') {
        final attributeNode = child.getAttribute('node') ?? '';
        final fromNode = items[attributeNode];
        if (fromNode?.isEmpty ?? true) {
          items[attributeNode] = <_Item>[];
        }
        for (final child in child.children.whereType<xml.XmlElement>()) {
          if (child.localName == 'item') {
            items[attributeNode]?.add(_Item.fromXML(child));
          }
          if (child.localName == 'retract') {
            final node = retracts[attributeNode] ?? <_Item>[];
            node.add(_Retract.fromXML(child));
          }
        }
      }
    }

    return PubSubEvent(
      payloads: payloads,
      items: items,
      retractItems: retracts,
    );
  }

  @override
  xml.XmlElement toXML() {
    final element = WhixpUtils.xmlElement('event', namespace: _eventNamespace);

    if (payloads?.isNotEmpty ?? false) {
      for (final payload in payloads!) {
        element.children.add(payload.toXML().copy());
      }
    }

    if (items?.isNotEmpty ?? false) {
      for (final item in items!.entries) {
        final itemsElement = WhixpUtils.xmlElement(
          'items',
          attributes: <String, String>{'node': item.key},
        );
        for (final node in item.value) {
          itemsElement.children.add(node.toXML().copy());
        }
        element.children.add(itemsElement);
      }
    }

    if (retractItems?.isNotEmpty ?? false) {
      for (final item in retractItems!.entries) {
        final itemsElement = WhixpUtils.xmlElement(
          'items',
          attributes: <String, String>{'node': item.key},
        );
        for (final node in item.value) {
          itemsElement.children.add(node.toXML().copy());
        }
        element.children.add(itemsElement);
      }
    }

    return element;
  }

  @override
  String get name => 'pubsubevent';

  @override
  String get tag => pubsubEventTag;
}

/// This stanza helps to support the ability to publish items. Any entity that
/// is allowed to publish items to node (i.e., a publisher or an owner) may do
/// so at any time by sending an IQ-set to the service containing a pubsub
/// element with a __<publish/>__ child.
///
/// * The <publish/> element MUST possess a `node` attribute, specifying the
/// NodeID of the node.
/// * Depending on the node configuration, the __<publish/>__ element MAY
/// contain no __<item/>__ elements or one __<item/>__ element.
///
/// see <https://xmpp.org/extensions/xep-0060.html#publisher-publish>
class _Publish {
  const _Publish({this.node, this.item});

  final String? node;
  final _Item? item;

  factory _Publish.fromXML(xml.XmlElement node) {
    String? nod;
    _Item? item;

    for (final attribute in node.attributes) {
      if (attribute.localName == 'node') {
        nod = attribute.value;
      }
    }

    for (final child in node.children.whereType<xml.XmlElement>()) {
      item = _Item.fromXML(child);
    }

    return _Publish(node: nod, item: item);
  }

  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();
    final attributes = <String, String>{};
    if (node?.isNotEmpty ?? false) attributes['node'] = node!;

    builder.element('publish', attributes: attributes);
    final element = builder.buildDocument().rootElement;

    if (item != null) element.children.add(item!.toXML().copy());

    return element;
  }
}

/// This retract stanzas will be send by the publisher to delete an item. The
/// __<retract/>__ element MUST possess a `node` attribute, MAY possess a
/// `notify` attribute, and MUST contain one __<item/>__ element; this item
/// element MUST be empty and MUST possess and `id` attribute.
///
/// ```xml
/// <iq type='set'
///     from='vsevex@example.com/mobile'
///     to='pubsub.example.com'
///     id='retract1'>
///   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
///     <retract node='someNode'>
///       <item id='ae890ac52d0df67ed7cfdf51b644e901'/>
///     </retract>
///   </pubsub>
/// </iq>
/// ```
class _Retract {
  const _Retract({this.node, this.notify, this.item});

  final String? node;
  final String? notify;
  final _Item? item;

  factory _Retract.fromXML(xml.XmlElement node) {
    String? nod;
    String? notify;
    _Item? item;

    for (final attribute in node.attributes) {
      if (attribute.localName == 'node') {
        nod = attribute.value;
      }
      if (attribute.localName == 'notify') {
        notify = attribute.value;
      }
    }

    for (final child in node.children.whereType<xml.XmlElement>()) {
      item = _Item.fromXML(child);
    }

    return _Retract(node: nod, notify: notify, item: item);
  }

  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();
    final attributes = <String, String>{};
    if (node?.isNotEmpty ?? false) attributes['node'] = node!;
    if (notify?.isNotEmpty ?? false) attributes['notify'] = notify!;

    builder.element('retract', attributes: attributes);
    final element = builder.buildDocument().rootElement;

    if (item != null) {
      element.children.add(item!.toXML().copy());
    }

    return element;
  }
}

class _Item {
  const _Item({this.id, this.publisher, this.payload, this.tune, this.mood});

  final String? id;
  final String? publisher;
  final Stanza? payload;
  final Tune? tune;
  final Mood? mood;

  factory _Item.fromXML(xml.XmlElement node) {
    String? id;
    String? publisher;
    Stanza? stanza;
    Tune? tune;
    Mood? mood;

    for (final attribute in node.attributes) {
      if (attribute.localName == 'id') {
        id = attribute.value;
      }
      if (attribute.localName == 'publisher') {
        publisher = attribute.value;
      }
    }

    for (final child in node.children.whereType<xml.XmlElement>()) {
      switch (child.localName) {
        case 'tune':
          tune = Tune.fromXML(child);
        case 'mood':
          mood = Mood.fromXML(child);
        default:
          final tag = WhixpUtils.generateNamespacedElement(child);
          stanza = Stanza.payloadFromXML(tag, child);
      }
    }

    return _Item(
      id: id,
      publisher: publisher,
      payload: stanza,
      tune: tune,
      mood: mood,
    );
  }

  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();
    final attributes = <String, String>{};
    if (id?.isNotEmpty ?? false) attributes['id'] = id!;
    if (publisher?.isNotEmpty ?? false) attributes['publisher'] = publisher!;

    builder.element('item', attributes: attributes);
    final element = builder.buildDocument().rootElement;

    if (tune != null) {
      element.children.add(tune!.toXML().copy());
    }
    if (mood != null) {
      element.children.add(mood!.toXML().copy());
    }
    if (payload != null) {
      element.children.add(payload!.toXML().copy());
    }

    return element;
  }

  @override
  String toString() =>
      '''PubSub Item (id: $id, publisher: $publisher, stanza: $payload, tune: $tune, mood: $mood) ''';
}
