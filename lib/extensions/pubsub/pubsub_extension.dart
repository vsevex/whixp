import 'package:echo/echo.dart';
import 'package:echo/src/constants.dart';

class PubSubExtension extends Extension {
  PubSubExtension() : super('pubsub-extension') {
    const pubsubNS = 'http://jabber.org/protocol/pubsub';

    echo!
      ..addNamespace('PUBSUB', pubsubNS)
      ..addNamespace(
        'PUBSUB_SUBSCRIBE_OPTIONS',
        '$pubsubNS#subsribe_options',
      )
      ..addNamespace('PUBSUB_ERRORS', '$pubsubNS#errors')
      ..addNamespace('PUBSUB_EVENT', '$pubsubNS#event')
      ..addNamespace('PUBSUB_OWNER', '$pubsubNS#owner')
      ..addNamespace('PUBSUB_AUTO_CREATE', '$pubsubNS#auto-create')
      ..addNamespace('PUBSUB_PUBLISH_OPTIONS', '$pubsubNS#publish-options')
      ..addNamespace('PUBSUB_NODE_CONFIG', '$pubsubNS#node-config')
      ..addNamespace(
        'PUBSUB_CREATE_AND_CONFIGURE',
        '$pubsubNS#create-and-configure',
      )
      ..addNamespace(
        'PUBSUB_SUBSCRIBE_AUTHORIZATION',
        '$pubsubNS#subscribe_authorization',
      )
      ..addNamespace('PUBSUB_GET_PENDING', '$pubsubNS#get-pending')
      ..addNamespace(
        'PUBSUB_MANAGE_SUBSCRIPTIONS',
        '$pubsubNS#manage-subscriptions',
      )
      ..addNamespace('PUBSUB_META_DATA', '$pubsubNS#meta-data')
      ..addNamespace('ATOM', 'http://www.w3.org/2005/Atom');
  }

  String? _jid;
  String? _service;
  bool _autoService = true;
  final _handler = <String, List<Handler>>{};

  @override
  void initialize(Echo echo) {
    super.echo = echo;
  }

  @override
  void changeStatus(EchoStatus status, String? condition) {
    if (_autoService && status == EchoStatus.connected) {
      _service = 'pubsub.${Echotils().getDomainFromJID(_jid!)}';
      _jid = echo!.jid;
    }
  }

  void connect(String jid, {String? service}) {
    String? inJid = jid;
    if (service == null) {
      service = jid;
      inJid = null;
    }

    _jid = inJid ?? echo!.jid;
    _service = service;
    _autoService = false;
  }

  void storeHandler(String node, Handler handler) {
    if (!_handler.containsKey(node) || _handler[node] == null) {
      _handler[node] = [];
    }
    _handler[node]!.add(handler);
  }

  void removeHandler(String node) {
    final temp = _handler[node];
    _handler[node] = [];

    if (temp != null && temp.isNotEmpty) {
      for (int i = 0; i < temp.length; i++) {
        echo!.deleteHandler(temp[i]);
      }
    }
  }

  Future<String> createNode(
    String node, {
    Map<String, String>? options,
    Future<bool> Function(XmlElement)? callback,
  }) async {
    final id = echo!.getUniqueId('pubsubcreatenode');

    final iq = EchoBuilder.iq(
      attributes: {
        'from': _jid,
        'to': _service,
        'type': 'set',
        'id': id,
      },
    ).c('pubsub', attributes: {'xmlns': ns['PUBSUB']!}).c(
      'create',
      attributes: {'node': node},
    );

    if (options != null) {
      iq.up().c('configure').form(ns['PUBSUB_NODE_CONFIG']!, options);
    }

    echo!.addHandler(callback, name: 'iq', id: id);
    await echo!.send(iq.nodeTree);

    return id;
  }

  Future<String> deleteNode(
    String node, {
    Future<bool> Function(XmlElement)? callback,
  }) async {
    final id = echo!.getUniqueId('pubsubdeletenode');
    final iq = EchoBuilder.iq(
      attributes: {
        'from': _jid,
        'to': _service,
        'type': 'set',
        'id': id,
      },
    ).c('pubsub', attributes: {'xlmns': ns['PUBSUB_OWNER']!}).c(
      'delete',
      attributes: {'node': node},
    );

    echo!.addHandler(callback, name: 'iq', id: id);
    await echo!.send(iq.nodeTree);

    return id;
  }

  Future<void> discoverNodes({
    void Function(XmlElement)? onSuccess,
    void Function(XmlElement?)? onFailure,
    int? timeout,
  }) {
    final iq = EchoBuilder.iq(
            attributes: {'from': _jid, 'to': _service, 'type': 'get'})
        .c('query', attributes: {'xmlns': ns['DISCO_ITEMS']!});

    return echo!.sendIQ(
      element: iq.nodeTree!,
      callback: onSuccess,
      onError: onFailure,
      timeout: timeout,
    );
  }

  Future<String> getConfig(
    String node, {
    Future<bool> Function(XmlElement)? callback,
  }) async {
    final id = echo!.getUniqueId('pubsubconfigurenode');

    final iq = EchoBuilder.iq(
      attributes: {'from': _jid, 'to': _service, 'type': 'get', 'id': id},
    ).c('pubsub', attributes: {'xmlns': ns['PUBSUB_OWNER']!}).c(
      'configure',
      attributes: {'node': node},
    );

    echo!.addHandler(callback, name: 'iq', id: id);
    await echo!.send(iq.nodeTree);

    return id;
  }

  Future<String> getDefaultNodeConfig({
    Future<bool> Function(XmlElement)? callback,
  }) async {
    final id = echo!.getUniqueId('pubsubdefaultnodeconfig');

    final iq = EchoBuilder.iq(
      attributes: {'from': _jid, 'to': _service, 'type': 'get', 'id': id},
    ).c('pubsub', attributes: {'xmlns': ns['PUBSUB_OWNER']!}).c('default');

    echo!.addHandler(callback, name: 'iq', id: id);
    await echo!.send(iq.nodeTree);

    return id;
  }

  Future<String> subscribe(
    String node, {
    Map<String, String>? options,
    String? bareJid,
    Future<bool> Function(XmlElement)? eventCallback,
    void Function(XmlElement)? onSuccess,
    void Function(XmlElement?)? onError,
  }) async {
    final id = echo!.getUniqueId('subscribenode');
    String jid = _jid!;

    if (bareJid != null) {
      jid = Echotils().getBareJIDFromJID(jid)!;
    }

    final iq = EchoBuilder.iq(
      attributes: {
        'from': jid,
        'to': _service,
        'type': 'set',
        'id': id,
      },
    ).c('pubsub', attributes: {'xmlns': ns['PUBSUB']!}).c(
      'subscribe',
      attributes: {'node': node, 'jid': jid},
    );

    if (options != null) {
      iq.up().c('options').form(ns['PUBSUB_SUBSCRIBE_OPTIONS']!, options);
    }

    final handler = echo!.addHandler(eventCallback, name: 'message');
    storeHandler(node, handler);
    await echo!
        .sendIQ(element: iq.nodeTree!, callback: onSuccess, onError: onError);

    return id;
  }

  Future<String> unsubsribe(
    String node,
    String jid, {
    String? subId,
    void Function(XmlElement)? onSuccess,
    void Function(XmlElement?)? onError,
  }) async {
    final id = echo!.getUniqueId('pubsubunsubscribenode');

    final iq = EchoBuilder.iq(
      attributes: {
        'from': _jid,
        'to': _service,
        'type': 'set',
        'id': id,
      },
    ).c('pubsub', attributes: {'xmlns': ns['PUBSUB']!}).c(
      'unsubscribe',
      attributes: {'node': node, 'jid': jid},
    );

    if (subId != null) {
      iq.addAttributes({'subid': subId});
    }

    await echo!
        .sendIQ(element: iq.nodeTree!, callback: onSuccess, onError: onError);
    removeHandler(node);
    return id;
  }

  Future<String> publish(
    String node,
    List<ListItem> items, {
    Future<bool> Function(XmlElement)? callback,
  }) async {
    final id = echo!.getUniqueId('pubsubpublishnode');

    final iq = EchoBuilder.iq(
      attributes: {'from': _jid, 'to': _service, 'type': 'set', 'id': id},
    ).c('pubsub', attributes: {'xmlns': ns['PUBSUB']!}).c(
      'publish',
      attributes: {
        'node': node,
        'jid': _jid!,
      },
    ).list('item', items);

    echo!.addHandler(callback, name: 'iq', id: id);
    await echo!.send(iq);

    return id;
  }

  Future<void> items(
    String node, {
    void Function(XmlElement)? onSuccess,
    void Function(XmlElement?)? onFailure,
    int? timeout,
  }) {
    final iq = EchoBuilder.iq(
            attributes: {'from': _jid, 'to': _service, 'type': 'get'})
        .c('pubsub', attributes: {'xmlns': ns['PUBSUB']!}).c(
      'items',
      attributes: {'node': node},
    );

    return echo!.sendIQ(
      element: iq.nodeTree!,
      callback: onSuccess,
      onError: onFailure,
      timeout: timeout,
    );
  }

  Future<String> getSubscriptions({
    Future<bool> Function(XmlElement)? callback,
  }) async {
    final id = echo!.getUniqueId('pubsubsubscriptions');

    final iq = EchoBuilder.iq(
      attributes: {
        'from': _jid,
        'to': _service,
        'type': 'get',
        'id': id,
      },
    ).c('pubsub', attributes: {'xlmns': ns['PUBSUB']!}).c('subscriptions');

    echo!.addHandler(callback, name: 'iq', id: id);
    await echo!.send(iq.nodeTree);

    return id;
  }

  Future<String> getNodeSubscriptions(
    String node, {
    Future<bool> Function(XmlElement)? callback,
  }) async {
    final id = echo!.getUniqueId('pubsubsubscriptions');

    final iq = EchoBuilder.iq(
      attributes: {'from': _jid, 'to': _service, 'type': 'get', 'id': id},
    ).c('pubsub', attributes: {'xmlns': ns['PUBSUB_OWNER']!}).c(
      'subscriptions',
      attributes: {'node': node},
    );

    echo!.addHandler(callback, name: 'iq', id: id);
    await echo!.send(iq.nodeTree);

    return id;
  }

  Future<String> getSubscriptionOptions(
    String node,
    String subId, {
    Future<bool> Function(XmlElement)? callback,
  }) async {
    final id = echo!.getUniqueId('pubsubsuboptions');

    final iq = EchoBuilder.iq(
      attributes: {
        'from': _jid,
        'to': _service,
        'type': 'get',
        'id': id,
      },
    ).c('pubsub', attributes: {'xmlns': ns['PUBSUB']!}).c(
      'options',
      attributes: {'node': node, 'jid': _jid!},
    );

    echo!.addHandler(callback, name: 'iq', id: id);
    await echo!.send(iq.nodeTree);

    return id;
  }
}

class ListItem {
  const ListItem(this.attributes, this.data);

  final Map<String, String> attributes;
  final dynamic data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListItem &&
          runtimeType == other.runtimeType &&
          attributes == other.attributes &&
          data == other.data;

  @override
  int get hashCode => attributes.hashCode ^ data.hashCode;

  @override
  String toString() => '''List Item: (Attributes: $attributes, data: $data)''';
}

extension IqX on EchoBuilder {
  XmlElement? form(String ns, Map<String, String> options) {
    final aX = nodeTree!.children
      ..addAll([
        Echotils.xmlElement(
          'x',
          attributes: {'xmlns': 'jabber:x:data', 'type': 'submit'},
        )!,
        Echotils.xmlElement(
          'field',
          attributes: {'var': 'FORM_TYPE', 'type': 'hidden'},
        )!,
        Echotils.xmlElement('value')!,
      ]);

    for (final i in options.values) {
      aX.addAll([
        Echotils.xmlElement('field', attributes: {'var': i})!,
        Echotils.xmlElement('value')!,
        Echotils.xmlTextNode(options[i]!)
      ]);
    }

    return nodeTree;
  }

  XmlElement? list(String tag, List<ListItem> items) {
    for (int i = 0; i < items.length; i++) {
      c(tag, attributes: items[i].attributes);
      nodeTree!.children.addAll([
        if (items[i].data is XmlElement)
          Echotils.copyElement(items[i].data as XmlNode)
        else
          Echotils.xmlTextNode(items[i].data as String)
      ]);

      up();
    }

    return nodeTree;
  }
}
