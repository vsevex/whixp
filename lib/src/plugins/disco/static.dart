part of 'disco.dart';

/// Most clients and basic bots just need to manage a few disco nodes that will
/// remain essentially static, but components will probably need fully dynamic
/// processing of service discovery information.
///
/// A collection of node handlers that [_StaticDisco] offers will keep static
/// sets of discovery data and objects in memory.
class _StaticDisco {
  /// Creates static discovery interface. Every possible combination of JID and
  /// node is stored by sets of "disco#info" and "disco#items" stanzas.
  ///
  /// Without any further processing, discovery data is kept in mermoy for later
  /// use in these stanzas.
  _StaticDisco(this.whixp);

  /// The [WhixpBase] instance. Mostly used to access the current transport
  /// instance.
  final WhixpBase whixp;
  final nodes = <Tuple3<String, String, String>, Map<String, XMLBase?>>{};

  Map<String, XMLBase?> addNode({String? jid, String? node, String? iqFrom}) {
    late String nodeJID;
    late String nodeIQFrom;

    if (jid == null) {
      nodeJID = whixp.transport.boundJID.toString();
    } else {
      nodeJID = jid;
    }
    if (iqFrom == null) {
      nodeIQFrom = '';
    } else {
      nodeIQFrom = iqFrom;
    }

    node ??= '';

    if (!nodes.containsKey(Tuple3(nodeJID, node, nodeIQFrom))) {
      final info = DiscoInformationAbstract();
      final items = DiscoItemsAbstract();
      final item = DiscoItem();

      items.registerPlugin(item, iterable: true);
      items.enable(item.name);
      info['node'] = node;
      items['node'] = node;

      nodes[Tuple3(nodeJID, node, nodeIQFrom)] = <String, XMLBase>{
        'information': info,
        'items': items,
      };
    }

    return nodes[Tuple3(nodeJID, node, nodeIQFrom)]!;
  }

  Map<String, XMLBase?> getNode({String? jid, String? node, String? iqFrom}) {
    late String nodeJID;
    late String nodeIQFrom;

    if (jid == null) {
      nodeJID = whixp.transport.boundJID.toString();
    } else {
      nodeJID = jid;
    }

    node ??= '';

    if (iqFrom == null) {
      nodeIQFrom = '';
    } else {
      nodeIQFrom = iqFrom;
    }

    if (!nodes.containsKey(Tuple3(nodeJID, node, nodeIQFrom))) {
      addNode(jid: nodeJID, node: node, iqFrom: nodeIQFrom);
    }

    return nodes[Tuple3(nodeJID, node, nodeIQFrom)]!;
  }

  DiscoveryInformation getInformation({
    String? jid,
    String? node,
    JabberID? iqFrom,
  }) {
    if (!nodeExists(jid: jid, node: node)) {
      if (node == null || node.isEmpty) {
        return DiscoveryInformation(DiscoInformationAbstract());
      } else {
        throw StanzaException(
          'Missing item exception occured on disco information retrieval',
          condition: 'item-not-found',
        );
      }
    } else {
      return DiscoveryInformation(
        DiscoInformationAbstract(
          element: getNode(jid: jid, node: node)['info']!.element,
        ),
      );
    }
  }

  DiscoItemsAbstract? getItems({
    String? jid,
    String? node,
    JabberID? iqFrom,
  }) {
    if (!nodeExists(jid: jid, node: node)) {
      if (node == null || node.isEmpty) {
        return DiscoItemsAbstract();
      } else {
        throw StanzaException(
          'Missing item exception occured on disco information retrieval',
          condition: 'item-not-found',
        );
      }
    } else {
      return getNode(jid: jid, node: node)['items'] as DiscoItemsAbstract?;
    }
  }

  /// Caches discovery information for an external jabber ID.
  void cacheInformation({
    String? jid,
    String? node,
    String? iqFrom,
    XMLBase? stanza,
  }) {
    XMLBase? information;
    if (stanza is IQ) {
      information = stanza['disco_info'] as XMLBase;
    } else {
      information = stanza;
    }

    final newNode = addNode(jid: jid, node: node, iqFrom: iqFrom);
    newNode['information'] = information;
  }

  /// Retrieves cached discovery information data.
  DiscoveryInformation? getCachedInformation({
    String? jid,
    String? node,
    String? iqFrom,
  }) {
    if (!nodeExists(jid: jid, node: node, iqFrom: iqFrom)) {
      return null;
    }

    return DiscoveryInformation(
      nodes[Tuple3(jid, node, iqFrom)]!['information']!
          as DiscoInformationAbstract,
    );
  }

  bool nodeExists({
    String? jid,
    String? node,
    String? iqFrom,
  }) {
    late String nodeJID;
    late String nodeIQFrom;
    if (jid == null) {
      nodeJID = whixp.transport.boundJID.full;
    } else {
      nodeJID = jid;
    }
    node ??= '';
    if (iqFrom == null) {
      nodeIQFrom = '';
    } else {
      nodeIQFrom = iqFrom;
    }

    return nodes.containsKey(Tuple3(nodeJID, node, nodeIQFrom));
  }

  /// Adds a feature to a JID/node combination.
  void addFeature(String feature, {String? jid, String? node}) {
    final newNode = addNode(jid: jid, node: node);
    if (newNode['information'] != null) {
      (newNode['information']! as DiscoInformationAbstract).addFeature(feature);
    }
  }

  /// Removes a feature from a JID/node combination.
  void removeFeature(String feature, {String? jid, String? node}) {
    if (nodeExists(jid: jid, node: node)) {
      if (getNode(jid: jid, node: node)['information'] != null) {
        (getNode(jid: jid, node: node)['information']!
                as DiscoInformationAbstract)
            .deleteFeature(feature);
      }
    }
  }
}
