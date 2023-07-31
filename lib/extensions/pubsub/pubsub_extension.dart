import 'dart:async';

import 'package:dartz/dartz.dart';

import 'package:echo/echo.dart';
import 'package:echo/src/constants.dart';

/// # PubSub Extension
///
/// XEP-0060: Publish-Subscribe [https://xmpp.org/extensions/xep-0060.html#intro-overview]
/// The XMPP publish-subscribe extension defined in this document provides a
/// framework for a wide variety of applications, including news feeds, content
/// syndication, extended presence, geolocation, avatar management, shared
/// bookmarks, auction and trading systems, workflow systems, network management
/// systems, NNTP gateways, profile management, and any other application that
/// requires event notifications.
///
/// This technology uses the classic "publish-subscribe" or "observer" design
/// pattern: a person or application publishes information, and an event
/// notification (with or without payload) is broadcasted to all authorized
/// subscribers.
class PubSubExtension extends Extension {
  /// This extension will take place under [_extensions] list of currently
  /// used [Echo] class with the name of `pubsub-extension`.
  ///
  /// Decleration of this extension require no parameter. So the usage of this
  /// extension needs to be like this:
  ///
  /// ### Usage
  /// ```dart
  /// final pubsub = PubSubExtension();
  /// if (status == EchoStatus.connected) {
  ///   log('Connection Established');
  ///   final pubsub = PubSubExtension();
  ///   echo.attachExtension(pubsub);
  ///   pubsub.connect(
  ///     'vsevex@chat.example.com/desktop',
  ///     service: 'pubsub.chat.example.com',
  ///   );
  ///
  ///   /// ...after connection several actions cone be done.
  /// }
  /// ```
  PubSubExtension() : super('pubsub-extension');

  /// The JID initializer.
  String? _jid;

  /// Local initializer to keep service data associated with the XMPP server.
  String? _service;

  /// Helper boolean (flag) for indicating that the connection status is needed
  /// to handle explicitly.
  bool _autoService = true;

  /// Local initializer to keep used handler list.
  final _handlers = <String, List<Handler>>{};

  @override
  void initialize(Echo echo) {
    super.echo = echo;

    /// Declare global pubsub namespace for further usages of this ns.
    const pubsubNS = 'http://jabber.org/protocol/pubsub';

    /// Add required namespaces to the [Echo] class.
    super.echo!
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

  @override
  void changeStatus(EchoStatus status, String? condition) {
    if (_autoService && status == EchoStatus.connected) {
      _service = 'pubsub.${Echotils().getDomainFromJID(_jid!)}';
      _jid = echo!.jid;
    }
  }

  /// Provides connection to the pubsub (publish-subscribe) service under the
  /// given Jabber ID. For example, the service name for the publish-subscribe
  /// service that works on the XMPP server can be "pubsub.example.com". In this
  /// case, this service name must be passed to the function over [service]
  /// property. After connection, if there is any node create action will take
  /// place, then the owner and creator of the corresponding node will be the
  /// JID which is currently connected to the service.
  ///
  /// * @param jid The node owner's JID.
  /// * @param service The name of the pubsub service.
  void connect(String jid, {String? service}) {
    /// Equal to new variable to allow making changes to the variable.
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
    if (!_handlers.containsKey(node) || _handlers[node] == null) {
      _handlers[node] = [];
    }
    _handlers[node]!.add(handler);
  }

  void removeHandler(String node) {
    final temp = _handlers[node];
    _handlers[node] = [];

    if (temp != null && temp.isNotEmpty) {
      for (int i = 0; i < temp.length; i++) {
        echo!.deleteHandler(temp[i]);
      }
    }
  }

  /// Responsible for creating a node in the XMPP server. This method can be
  /// used to create leaf and collection nodes (through options Map).
  ///
  /// * @param node A [String] representing the node that is going to be
  /// created.
  /// * @param options Optional [Map<String, String>] parameter to create a node
  /// using options such as pubsub#collection or pubsub#node_type.
  /// * @param callback Optional Function parameter to invoke a method when
  /// there is a received response for the IQ stanza.
  /// * @return A [String] resolves to the ID of the sent IQ stanza.This ID can
  /// be used to track the response or correlate it with the original request.
  ///
  /// ### Usage
  /// ```dart
  /// final nodeID = await pubsub.createNode('exampleNode', callback: (element) {
  ///   log('Node created.');
  ///
  ///   return true;
  /// });
  /// ```
  Future<String> createNode(
    String node, {
    Map<String, String>? options,
    FutureOr<void> Function(XmlElement)? resultCallback,
    FutureOr<void> Function(EchoException)? errorCallback,
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

    await echo!.sendIQ(
      element: iq.nodeTree!,
      resultCallback: resultCallback,
      errorCallback: errorCallback,
      waitForResult: true,
    );

    return id;
  }

  /// This method is used to delete a specific PubSub node from an XMPP server.
  /// It sends an IQ (Info/Query) stanza with a "set" type to initiate the
  /// deletion of the specified node.
  ///
  /// * @param callback Function to add to handler to indicate if it will be
  /// kept in the cycle of handlers.
  /// * @param node The identifier of the PubSub node to be deleted.
  /// * @param An optional callback function that will be invoked when a
  /// response to the IQ stanza is received.
  ///
  /// ### Usage
  /// ```dart
  /// final nodeID = await pubsub.deleteNode('exampleNode', callback: (element) {
  ///   log('Node deleted.');
  ///
  ///   return true;
  /// });
  /// ```
  Future<String> deleteNode(
    String node, {
    FutureOr<bool> Function(XmlElement)? callback,
    FutureOr<void> Function(XmlElement)? resultCallback,
    FutureOr<void> Function(EchoException)? errorCallback,
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

    final completer = Completer<Either<XmlElement, EchoException>>();

    echo!.addHandler(callback, completer: completer, name: 'iq', id: id);
    await echo!.send(iq, completer, resultCallback, errorCallback);

    return id;
  }

  /// Allows discovering nodes which is currently available on the server.
  /// The main responsibility of this method is to get all nodes that currently
  /// exist.
  ///
  /// * @param resultCallback Used to determine if node discovery is successful
  /// and if there is data to show.
  /// * @param errorCallback Used to determine if there is an error while
  /// getting existing nodes.
  ///
  /// ### Usage
  /// ```dart
  /// final pubsub = PubSubExtension();
  /// echo.attachExtension(pubsub);
  ///
  /// await pubsub.discoverNodes(
  ///   resultCallback: (element) {
  ///     log(element);
  ///     /// possible output: <iq xmlns="jabber:client" type="result"
  ///     /// id="2c1e66aa-b9ee-4346-a44a-ff32a87121a0:sendIQ"
  ///     /// from="pubsub.chat.example.com"
  ///     /// to="vsevex@chat.example.com/resource"><query
  ///     /// xmlns="http://jabber.org/protocol/disco#items"><item
  ///     /// jid="pubsub.chat.example.com" name="All Registrants"
  ///     /// node="registration"/></query></iq>
  ///   }
  /// );
  /// ```
  Future<void> discoverNodes({
    FutureOr<void> Function(XmlElement)? resultCallback,
    FutureOr<void> Function(EchoException)? errorCallback,
    int? timeout,
  }) async {
    /// Creates IQ stanza to send for the discovery of currently available
    /// nodes.
    final iq = EchoBuilder.iq(
      attributes: {'from': _jid, 'to': _service, 'type': 'get'},
    ).c('query', attributes: {'xmlns': ns['DISCO_ITEMS']!});

    return echo!.sendIQ(
      element: iq.nodeTree!,
      resultCallback: resultCallback,
      errorCallback: errorCallback,
      waitForResult: true,
      timeout: timeout,
    );
  }

  /// This method is used to retrieve the configuration of a specific PubSub
  /// node on an XMPP server. It sends an IQ (Info/Query) stanza with a `get`
  /// type to request the configuration of the specified node.
  ///
  /// * @param node The identifier of the PubSub node for which the
  /// configuration is requested.
  /// * @param callback Optional Function parameter to invoke a method when
  /// there is a received response for the IQ stanza.
  /// * @return A [String] resolves to the ID of the sent IQ stanza.This ID can
  /// be used to track the response or correlate it with the original request.
  String getConfig(
    String node, [
    FutureOr<bool> Function(XmlElement)? callback,
    FutureOr<void> Function(XmlElement)? resultCallback,
    FutureOr<void> Function(EchoException)? errorCallback,
  ]) {
    final id = echo!.getUniqueId('pubsubconfigurenode');

    final iq = EchoBuilder.iq(
      attributes: {'from': _jid, 'to': _service, 'type': 'get', 'id': id},
    ).c('pubsub', attributes: {'xmlns': ns['PUBSUB_OWNER']!}).c(
      'configure',
      attributes: {'node': node},
    );

    echo!.addHandler(
      callback,
      resultCallback: resultCallback,
      errorCallback: errorCallback,
      name: 'iq',
      id: id,
    );

    echo!.send(iq);

    return id;
  }

  /// This method is used to retrieve the default configuration for creating a
  /// new PubSub node on an XMPP server. It sends an IQ (Info/Query) stanza with
  /// a `get` type to request the default configuration.
  ///
  /// * @param callback An optional callback function that will be invoked when
  /// a response to the IQ stanza is received. This callback can be used to
  /// process the response or perform additional actions based on the received
  /// data.
  /// * @return A [String] resolves to the ID of the sent IQ stanza.This ID can
  /// be used to track the response or correlate it with the original request.
  String getDefaultNodeConfig([FutureOr<bool> Function(XmlElement)? callback]) {
    final id = echo!.getUniqueId('pubsubdefaultnodeconfig');

    final iq = EchoBuilder.iq(
      attributes: {'from': _jid, 'to': _service, 'type': 'get', 'id': id},
    ).c('pubsub', attributes: {'xmlns': ns['PUBSUB_OWNER']!}).c('default');

    echo!.addHandler(callback, name: 'iq', id: id);
    echo!.send(iq);

    return id;
  }

  /// This method is used to subscribe to a specific PubSub node on an XMPP
  /// server. It sends an IQ (Info/Query) stanza with a `set` type to initiate
  /// the subscription request.
  ///
  /// * @param node The identifier of the PubSub node to which the subscription
  /// is requested.
  /// * @param options An optional [Map<String, String>] of subscription options
  /// that can be customized based on the server's capabilities.
  /// * @param bareJID A flag indicating whether the subscription should use the
  /// bare JID format (true) or the full JID format (false) for the subscriber's
  /// JID. By default, it is set to false (full JID format).
  /// * @param callback An optional callback function that will be invoked when
  /// a related event occurs, such as receiving a notification or update related
  /// to the subscription.
  /// * @param messageCallback An optional callback function that will be
  /// invoked when a successful response to the IQ stanza is received.
  /// * @param messageErrorCallback An optional callback function that will be
  /// invoked when an error response or no response to the IQ stanza is
  /// received.
  /// * @return A [String] that resolves to the ID of the sent IQ stanza.
  ///
  /// ### Usage
  /// ```dart
  /// final subscriptionID = await pubsub.subscribe('exampleNode');
  /// ```
  Future<String> subscribe(
    String node, {
    Map<String, String>? options,
    bool bareJID = false,
    FutureOr<bool> Function(XmlElement)? callback,
    FutureOr<void> Function(XmlElement)? messageCallback,
    FutureOr<void> Function(EchoException)? messageErrorCallback,
  }) async {
    final id = echo!.getUniqueId('subscribenode');
    String jid = _jid!;

    if (bareJID) {
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

    final handler = echo!.addHandler(
      callback,
      name: 'message',
      resultCallback: messageCallback,
      errorCallback: messageErrorCallback,
    );
    storeHandler(node, handler);
    await echo!.sendIQ(element: iq.nodeTree!, waitForResult: true);

    return id;
  }

  /// This method is used to unsubscribe from a specific PubSub node on an XMPP
  /// server. It sends an IQ (Info/Query) stanza with a `set` type to initiate
  /// the unsubscribe action.
  ///
  /// * @param node The identifier of the PubSub node from which the
  /// unsubscription is requested.
  /// * @param jid The Jabber ID (JID) of the subscriber to be unsubscribed.
  /// * @param subID An optional subscription ID that uniquely identifies the
  /// subscription to be unsubscribed. If provided, only the specified
  /// subscription will be unsubscribed. If not provided, all subscriptions for
  /// the specified JID on the given node will be unsubscribed.
  /// * @param resultCallback An optional callback function that will be
  /// invoked when a successful response to the IQ stanza is received.
  /// * @param errorCallback An optional callback function that will be invoked
  /// when an error response or no response to the IQ stanza is received.
  /// * @return A [String] that resolves to the ID of the sent IQ stanza.
  Future<String> unsubsribe(
    String node,
    String jid, {
    String? subID,
    FutureOr<bool> Function(XmlElement)? resultCallback,
    FutureOr<bool> Function(EchoException)? errorCallback,
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

    if (subID != null) {
      iq.addAttributes({'subid': subID});
    }

    await echo!.sendIQ(
      element: iq.nodeTree!,
      resultCallback: resultCallback,
      errorCallback: errorCallback,
      waitForResult: true,
    );
    removeHandler(node);
    return id;
  }

  /// This method is used to publish items on a specific PubSub node in an XMPP
  /// server. It sends an IQ (Info/Query) stanza with a `set` type to publish
  /// the provided items on the specified node.
  ///
  /// * @param node The identifier of the PubSub node on which the items will
  /// be published.
  /// * @param items A [List] of `PubSubItem` objects representing the items to
  /// be published. Each `PubSubItem` consists of attributes (a map of key-value
  /// pairs) and data (the content of the item).
  ///
  /// (For further information refer to the [PubSubItem] class)
  /// * @param callback An optional callback function that will be invoked when
  /// a response to the IQ stanza is received.
  /// * @return A [String] that resolves to the ID of the published item.
  ///
  /// ### Usage
  /// ```dart
  /// await pubsub.publish('exampleNode', items: [PubSubItem(
  ///          attributes: {'id': 'someID'},
  ///          data: Echotils.xmlElement('element', text: 'data'),
  ///        )]);
  /// ```
  Future<String> publish(
    String node,
    List<PubSubItem> items, [
    FutureOr<bool> Function(XmlElement)? callback,
    FutureOr<void> Function(XmlElement)? resultCallback,
    FutureOr<void> Function(EchoException)? errorCallback,
  ]) async {
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

    final completer = Completer<Either<XmlElement, EchoException>>();

    echo!.addHandler(callback, name: 'iq', id: id, completer: completer);
    await echo!.send(iq, completer, resultCallback, errorCallback);

    return id;
  }

  /// This method is used to retrieve the items published on a specific PubSub
  /// node in an XMPP server. It sends an IQ (Info/Query) stanza with a `get`
  /// type to request the items associated with the specified node.
  ///
  /// * @param node The identifier of the PubSub node for which the items are
  /// requested.
  /// * @param resultCallback (Function) An optional callback function that
  /// will be invoked when a successful response to the IQ stanza is received.
  /// It can be used to process the received items XML and perform any necessary
  /// actions.
  /// * @param errorCallback An optional callback function that will be invoked
  /// when an error response or no response to the IQ stanza is received.
  /// * @param timeout An optional timeout value (in milliseconds) to specify
  /// the maximum amount of time to wait for a response to the IQ stanza.
  ///
  /// ### Usage
  /// ```dart
  /// await pubsub.getItems(
  ///   'exampleNode',
  ///   resultCallback: (element) {
  ///     log(element.toString()); /// ...outputs retrieved items stanza.
  ///   },
  ///   onFailure: (failureElement) {
  ///     log(failureElement.toString()); /// ...prints if there is an error
  ///                                     /// fetching items.
  ///   },
  ///   timeout: 1000,
  /// );
  /// ```
  Future<void> getItems(
    String node, {
    FutureOr<bool> Function(XmlElement)? resultCallback,
    FutureOr<bool> Function(EchoException)? errorCallback,
    int? timeout,
  }) async {
    final iq = EchoBuilder.iq(
      attributes: {'from': _jid, 'to': _service, 'type': 'get'},
    ).c('pubsub', attributes: {'xmlns': ns['PUBSUB']!}).c(
      'items',
      attributes: {'node': node},
    );

    return echo!.sendIQ(
      element: iq.nodeTree!,
      resultCallback: resultCallback,
      errorCallback: errorCallback,
      waitForResult: true,
      timeout: timeout,
    );
  }

  /// This method is used to retrieve all the subscriptions associated with the
  /// user's account on an XMPP server. It sends an IQ (Info/Query) stanza with
  /// a `get` type to request the subscriptions.
  ///
  /// * @param callback (Function) An optional callback function that will be
  /// invoked when a response to the IQ stanza is received. This callback can
  /// be used to process the response or perform additional actions based on the
  /// data.
  /// * @return A [String] that resolves to the ID of the sent IQ stanza.
  ///
  /// ### Usage
  /// ```dart
  /// final id = await pubsub.getSubscriptions(callback: (element) {
  ///   log(element.toString()); /// ...outputs available subscriptions which the user is
  ///                 /// currently subscribed.
  ///   return true;
  /// });
  /// ```
  Future<String> getSubscriptions([
    FutureOr<bool> Function(XmlElement)? callback,
    FutureOr<void> Function(XmlElement)? resultCallback,
    FutureOr<void> Function(EchoException)? errorCallback,
  ]) async {
    final id = echo!.getUniqueId('pubsubsubscriptions');

    final iq = EchoBuilder.iq(
      attributes: {
        'from': _jid,
        'to': _service,
        'type': 'get',
        'id': id,
      },
    ).c('pubsub', attributes: {'xmlns': ns['PUBSUB']!}).c('subscriptions');

    await echo!.sendIQ(
      element: iq.nodeTree!,
      resultCallback: resultCallback,
      errorCallback: errorCallback,
    );

    return id;
  }

  /// This method is used to retrieve the subscriptions associated with a
  /// specific PubSub node on an XMPP server. It sends an IQ (Info/Query) stanza
  /// with a `get` type to request the subscriptions for the specified node.
  ///
  /// * @param node The identifier of the PubSub node for which the
  /// subscriptions are requested.
  /// * @param resultCallback (Function) An optional callback function that
  /// will be invoked when a successful response to the IQ stanza is received.
  /// It can be used to process the received items XML and perform any necessary
  /// actions.
  /// * @param errorCallback An optional callback function that will be invoked
  /// when an error response or no response to the IQ stanza is received.
  /// * @param callback (Function) An optional callback function that will be
  /// invoked when a response to the IQ stanza is received. This callback can
  /// be used to process the response or perform additional actions based on
  /// the received data.
  /// * @return A [String] that resolves to the ID of the sent IQ stanza.
  ///
  /// ### Usage
  /// ```dart
  /// final id = await pubsub.getNodeSubscriptions('exampleNode', callback: (element) {
  ///   log(element.toString());
  ///
  ///   return true;
  /// });
  /// ```
  Future<String> getNodeSubscriptions(
    String node, [
    FutureOr<bool> Function(XmlElement)? callback,
    FutureOr<void> Function(XmlElement)? resultCallback,
    FutureOr<void> Function(EchoException)? errorCallback,
  ]) async {
    final id = echo!.getUniqueId('pubsubsubscriptions');

    final iq = EchoBuilder.iq(
      attributes: {'from': _jid, 'to': _service, 'type': 'get', 'id': id},
    ).c('pubsub', attributes: {'xmlns': ns['PUBSUB_OWNER']!}).c(
      'subscriptions',
      attributes: {'node': node},
    );

    final completer = Completer<Either<XmlElement, EchoException>>();

    echo!.addHandler(callback, completer: completer, name: 'iq', id: id);
    await echo!.send(iq, completer, resultCallback, errorCallback);

    return id;
  }

  /// This method is used to retrieve the subscription options for a specific
  /// subscription on a PubSub node in an XMPP server. It sends an IQ
  /// (Info/Query) stanza with a `get` type to request the options associated
  /// with the specified subscription.
  ///
  /// * @param node The identifier of the PubSub node for which options are
  /// requested.
  /// * @param subID The identifier of the subscription for which options are
  /// requested.
  /// * @param resultCallback (Function) An optional callback function that
  /// will be invoked when a successful response to the IQ stanza is received.
  /// It can be used to process the received items XML and perform any necessary
  /// actions.
  /// * @param errorCallback An optional callback function that will be invoked
  /// when an error response or no response to the IQ stanza is received.
  /// * @param callback (Function) An optional callback function which returns
  /// bool or Future<bool>. This callback can be used to process the response or
  /// perform additional actions based on the received data.
  /// * @return A [String] that resolves to the ID of the sent IQ stanza.
  ///
  /// ### Usage
  /// ```dart
  /// final id = await pubsub.getSubscriptionOptions('exampleNode',
  ///   callback: (element) {
  ///     log(element.toString()); /// ...outputs subscription options for all leaf nodes or
  ///                   /// for the given subscription only.
  ///
  ///     return true;
  ///   },
  /// );
  /// ```
  Future<String> getSubscriptionOptions(
    String node, {
    String? subID,
    FutureOr<bool> Function(XmlElement)? callback,
    FutureOr<void> Function(XmlElement)? resultCallback,
    FutureOr<void> Function(EchoException)? errorCallback,
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

    if (subID != null) {
      iq.addAttributes({'subid': subID});
    }

    final completer = Completer<Either<XmlElement, EchoException>>();

    echo!.addHandler(callback, completer: completer, name: 'iq', id: id);
    await echo!.send(iq, completer, resultCallback, errorCallback);

    return id;
  }
}

/// Represents an item to be published in the PubSub extension.
///
/// The method `publish` is used to publish items to the desired node. And this
/// class is responsible for sending the item in the stanza to publish in the
/// leaf node.
class PubSubItem {
  /// Creates instance for [PubSubItem] with the given params. Both params are
  /// required.
  const PubSubItem({required this.attributes, required this.data});

  /// A [Map<String, String>] of key-value pairs representing the attributes
  /// associated with the item.
  final Map<String, String> attributes;

  /// The content/data of the item. Can be either [String] or [XmlElement].
  final dynamic data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PubSubItem &&
          runtimeType == other.runtimeType &&
          attributes == other.attributes &&
          data == other.data;

  @override
  int get hashCode => attributes.hashCode ^ data.hashCode;

  @override
  String toString() =>
      '''PUBSUB List Item: (Attributes: $attributes, data: $data)''';
}

/// This extension provides an additional method called list on the
/// [EchoBuilder] class.
extension IqX on EchoBuilder {
  /// It facilitates the creation of XML elements for a form submission within
  /// an IQ (Info/Query) stanza.
  ///
  /// This method generates XML elements to represent a form submission within
  /// an IQ stanza. It adds the necessary fields and values based on the
  /// provided options.
  ///
  /// * @param ns The XML namespace for the form, typically set to 'jabber:x:data'.
  /// * @param options A [Map<String, String>] of options representing the
  /// fields and their corresponding values for the form.
  /// * @return The modified [EchoBuilder] instance, allowing for method
  /// chaining.
  EchoBuilder? form(String ns, Map<String, String> options) {
    c('x', attributes: {'xmlns': 'jabber:x:data', 'type': 'submit'}).c(
      'field',
      attributes: {'var': 'FORM_TYPE', 'type': 'hidden'},
    ).c('value');

    options.forEach(
      (key, value) =>
          up().up().c('field', attributes: {'var': key}).c('value').t(value),
    );

    return this;
  }

  /// It facilitates the creation of XML elements for a list of [PubSubItem]
  /// objects, allowing for easy inclusion of these items within an IQ
  /// (Info/Query) stanza.
  ///
  /// This method iterates through the provided list of [PubSubItem] objects
  /// and adds XML elements to the [EchoBuilder] instance accordingly. It
  /// supports both attribute-based and content-based items.
  ///
  /// * @param tag The tag name to be used for the XML elements represents the
  /// items.
  /// * @param items A [List] of [PubSubItem] objects representing the items
  /// to be included in the XML.
  /// * @return The modified [EchoBuilder] instance, allowing for method
  /// chaining.
  ///
  /// ### Usage
  /// ```dart
  /// final builder = EchoBuilder.iq(
  ///   attributes: {'from': _jid, 'to': _service, 'type': 'set', 'id': id},
  /// );
  ///
  /// /// ... this builder can be extended using this extension method.
  ///  builder.list('item', [
  ///        PubSubItem(
  ///          attributes: {'id': 'autoGeneratedID'},
  ///          data: EchoTils.xmlElement('someElement', text: 'data'),
  ///        )
  ///      ]);
  /// ```
  EchoBuilder? list(String tag, List<PubSubItem> items) {
    for (int i = 0; i < items.length; i++) {
      c(tag, attributes: items[i].attributes);
      if (items[i].data is XmlElement) {
        cnode(items[i].data as XmlElement);
      } else {
        t(items[i].data as String);
      }
    }

    /// Return the parent node of the given [EchoBuilder].
    return up();
  }
}
