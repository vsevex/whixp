import 'dart:async';

import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/plugins/plugins.dart';
import 'package:whixp/src/stanza/atom.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/message.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/stream/matcher/matcher.dart';
import 'package:whixp/src/utils/utils.dart';
import 'package:whixp/src/whixp.dart';

import 'package:xml/xml.dart' as xml;

part 'event.dart';
part 'stanza.dart';

final _$namespace = WhixpUtils.getNamespace('PUBSUB');
final _$event = '${WhixpUtils.getNamespace('PUBSUB')}#event';
final _$owner = '${WhixpUtils.getNamespace('PUBSUB')}#owner';

/// # PubSub
///
/// [PubSub] is designed to facilitate the integration of XMPP's
/// Publish-Subscribe service functionality to the [Whixp] package.
///
/// This is a messaging pattern that allows efficient and scalable distribution
/// of information.
///
/// ## Purpose
/// The primary purpose of this plugin is to simplify the process of working
/// with XMPP pubsub features within Dart & Flutter applications. It absracts
/// the complexities of the XMPP protocol, providing straightforward API to
/// interact with pubsub nodes on an XMPP server.
///
/// ### Features
/// * You can easily create, configure, and manage pubsub nodes on the XMPP
/// server.
/// * You can publish data to specific pubsub nodes, allow information
/// distribution to interested subscribers.
/// * It gives ability to subscribe to pubsub nodes to receive real-time
/// updates when new data is published.
///
/// More information about this service and the server implementation can be
/// found in the following link:
/// <https://xmpp.org/extensions/xep-0060.html>
class PubSub extends PluginBase {
  /// ### Example:
  /// ```dart
  /// void main() {
  ///   final whixp = Whixp(); /// ...construct this instance
  ///   final pubsub = PubSub();
  ///   whixp.registerPlugin(pubsub);
  ///
  ///   whixp.connect();
  ///   whixp.addEventHandler('sessionStart', (_) async {
  ///     whixp.getRoster();
  //      whixp.sendPresence();

  ///     await pubsub.getNodeConfig(JabberID('vsevex@example.com'));
  ///   });
  /// }
  /// ```
  PubSub()
      : super(
          'pubsub',
          description: 'XEP-0060: Publish-Subscribe',
          dependencies: <String>{'disco', 'forms', 'RSM'},
        );

  RSM? _rsm;
  ServiceDiscovery? _disco;
  late final _nodeEvents = <String, String>{};
  Iterator<Future<StanzaBase?>>? _iterator;

  @override
  void pluginInitialize() {
    _rsm = base.getPluginInstance<RSM>('RSM');
    _disco = base.getPluginInstance<ServiceDiscovery>('disco');
    _iterator = null;

    base.transport
      ..registerHandler(
        CallbackHandler(
          'PubSub Items',
          (stanza) => _handleEventItems(stanza as Message),
          matcher: StanzaPathMatcher('message/pubsub_event/item'),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'PubSub Subscription',
          (stanza) => _handleEventSubscription(stanza as Message),
          matcher: StanzaPathMatcher('message/pubsub_event/subscription'),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'PubSub Configuration',
          (stanza) => _handleEventConfiguration(stanza as Message),
          matcher: StanzaPathMatcher('message/pubsub_event/configuration'),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'PubSub Delete',
          (stanza) => _handleEventDelete(stanza as Message),
          matcher: StanzaPathMatcher('message/pubsub_event/delete'),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'PubSub Delete',
          (stanza) => _handleEventPurge(stanza as Message),
          matcher: StanzaPathMatcher('message/pubsub_event/purge'),
        ),
      );
  }

  void _handleEventItems(Message message) {
    final event = message['pubsub_event'] as PubSubEvent;
    final items = event['items'] as PubSubEventItems;

    final multi = items.iterables.length > 1;
    final node = items['node'] as String;
    final values = <String, dynamic>{};

    if (multi) {
      values.addAll(message.values);
      values.remove('pubsub_event');
    }

    for (final item in items.iterables) {
      final name = _nodeEvents[node];
      String type = 'publish';
      if (item.name == 'retract') {
        type = 'retract';
      }

      if (multi) {
        final condensed = Message();
        condensed.values = values;
        final items = (condensed['pubsub_event'] as PubSubEvent)['items']
            as PubSubEventItems;
        items['node'] = node;
        items.add(item);
        base.transport
            .emit<Message>('pubsub${type.capitalize()}', data: message);
        if (name != null && name.isNotEmpty) {
          base.transport.emit<Message>('${name}_$type', data: condensed);
        }
      } else {
        base.transport
            .emit<Message>('pubsub${type.capitalize()}', data: message);
        if (name != null && name.isNotEmpty) {
          base.transport.emit<Message>('${name}_$type', data: message);
        }
      }
    }
  }

  void _handleEventSubscription(Message message) {
    final node = ((message['pubsub_event'] as PubSubEvent)['subscription']
        as PubSubEventSubscription)['node'] as String;
    final eventName = _nodeEvents[node];

    base.transport.emit<Message>('pubsubSubscription', data: message);
    if (eventName != null) {
      base.transport.emit<Message>('${eventName}Subscription', data: message);
    }
  }

  void _handleEventConfiguration(Message message) {
    final node = ((message['pubsub_event'] as PubSubEvent)['configuration']
        as PubSubEventConfiguration)['node'] as String;
    final eventName = _nodeEvents[node];

    base.transport.emit<Message>('pubsubConfiguration', data: message);
    if (eventName != null) {
      base.transport.emit<Message>('${eventName}Config', data: message);
    }
  }

  void _handleEventDelete(Message message) {
    final node = ((message['pubsub_event'] as PubSubEvent)['delete']
        as PubSubEventDelete)['node'] as String;
    final eventName = _nodeEvents[node];

    base.transport.emit<Message>('pubsubDelete', data: message);
    if (eventName != null) {
      base.transport.emit<Message>('${eventName}Delete', data: message);
    }
  }

  void _handleEventPurge(Message message) {
    final node = ((message['pubsub_event'] as PubSubEvent)['purge']
        as PubSubEventPurge)['node'] as String;
    final eventName = _nodeEvents[node];

    base.transport.emit<Message>('pubsubPurge', data: message);
    if (eventName != null) {
      base.transport.emit<Message>('${eventName}Purge', data: message);
    }
  }

  /// Maps [node] names to specified [eventName].
  ///
  /// When a pubsub event is received for the given [node], raise the provided
  /// event.
  ///
  /// ### Example:
  /// ```dart
  /// final pubsub = PubSub();
  ///
  /// pubsub.mapNodeEvent('http://jabber.org/protocol/tune', 'userTune');
  /// ```
  ///
  /// This code will produce the events 'userTunePublish' and 'userTuneRetract'
  /// when the respective notifications are received from the node
  /// 'http://jabber.org/protocol/tune', among other events.
  void mapNodeEvent(String node, String eventName) =>
      _nodeEvents[node] = eventName;

  /// Creates a new [node]. This method works in two different ways:
  ///
  /// 1. Creates a node with default configuration for the specified [nodeType].
  /// 2. Creates and configures a [node] simultaneously.
  ///
  /// If no [config] form is provided, the node will be created using the
  /// server's default configuration.
  ///
  /// If no [node] name is provided, the server may generate a node ID for the
  /// node.
  ///
  /// These methods, along with method-specific error conditions, are explained
  /// more fully in the following link:
  ///
  /// see <https://xmpp.org/extensions/xep-0060.html#owner>
  ///
  /// Furthermore, a server may use a different name for the node than the one
  /// provided, so be sure to check the result stanza for a server assigned
  /// name.
  ///
  /// [jid] should be provided as the JID of the pubsub service.
  ///
  /// ### Example:
  /// ```dart
  /// void main() {
  ///   final pubsub = PubSub();
  ///   whixp.registerPlugin()
  ///
  ///   whixp.addEventHandler('sessionStart', (_) async {
  ///     await pubsub.createNode(
  ///       JabberID('nameofsomething@example.com'),
  ///       node: 'nodeName',
  ///     );
  ///   });
  /// }
  /// ```
  ///
  /// The rest of the parameters are related with the [IQ] stanza and each of
  /// them are responsible what to do when the server send the response. The
  /// server can send result stanza, error type stanza or the request can be
  /// timed out. [timeout] defaults to `10` seconds. If there is not any result
  /// or error from the server after the given seconds, then client stops to
  /// wait for an answer.
  FutureOr<IQ> createNode<T>(
    JabberID jid, {
    String? node,
    Form? config,
    String? nodeType,
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = base.makeIQSet(iqTo: jid, iqFrom: iqFrom);
    ((iq['pubsub'] as PubSubStanza)['create'] as PubSubCreate)['node'] = node;

    if (config != null) {
      const formType = 'http://jabber.org/protocol/pubsub#node_config';
      if (config.fields.containsKey('FORM_TYPE')) {
        final field = config.fields['FORM_TYPE'];
        if (field != null) {
          field['value'] = formType;
        }
      } else {
        config.addField(
          variable: 'FORM_TYPE',
          formType: 'hidden',
          value: formType,
        );
      }
      if (nodeType != null) {
        if (config.fields.containsKey('pubsub#node_type')) {
          final field = config.fields['pubsub#node_type'];
          if (field != null) {
            field['value'] = nodeType;
          }
        } else {
          config.addField(variable: 'pubsub#node_type', value: nodeType);
        }
      }
      (iq['pubsub'] as PubSubStanza).add(config);
    }

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Adds a new item to a [node], or edits an existing item.
  ///
  /// [PubSub] client service supports the ability to publish items. Any entity
  /// that is allowed to publish items to a node (publisher or owner) may do so
  /// at any time by sending an IQ-set to the service containing a pubsub
  /// element.
  ///
  /// When including a payload and you do not provide an [id], then the service
  /// will generally create an [id] for you.
  ///
  /// Publish [options] may be specified, and how those options are processed is
  /// left to the service, such as treating the options as preconditions that
  /// the [node]'s settings must match.
  ///
  /// For more information related to this ability of the service, please refer
  /// to:
  /// <https://xmpp.org/extensions/xep-0060.html#publisher-publish>
  ///
  /// For publishing [options]:
  /// <br><https://xmpp.org/extensions/xep-0060.html#publisher-publish-options>
  ///
  /// [jid] should be provided as the JID of the pubsub service.
  ///
  /// The [payload] MUST be in the [XMLBase] or [xml.XmlElement] type or it will
  /// throw an assertion exception.
  ///
  /// The rest of the parameters are related with the [IQ] stanza and each of
  /// them are responsible what to do when the server send the response. The
  /// server can send result stanza, error type stanza or the request can be
  /// timed out. [timeout] defaults to `10` seconds. If there is not any result
  /// or error from the server after the given seconds, then client stops to
  /// wait for an answer.
  FutureOr<IQ> publish<T>(
    JabberID jid,
    String node, {
    String? id,
    Form? options,
    JabberID? iqFrom,
    dynamic payload,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = base.makeIQSet(iqTo: jid, iqFrom: iqFrom);
    final publish = (iq['pubsub'] as PubSubStanza)['publish'] as PubSubPublish;
    publish['node'] = node;
    final item = publish['item'] as PubSubItem;
    if (id != null) {
      item['id'] = id;
    }
    if (payload != null) {
      assert(
        payload is XMLBase || payload is xml.XmlElement,
        'The provided payload must be either XMLBase or XmlElement',
      );
      item['payload'] = payload;
    }
    (iq['pubsub'] as PubSubStanza)['publish_options'] = options;

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Subscribes to updates from a pubsub node.
  ///
  /// When an entity wishes to subscribe to a node, it sends a subscription
  /// request to the pubsub service. The request is an IQ-set where the
  /// __<pubsub/>__ element contains one and only one __<subscribe/>__ element.
  ///
  /// The rules for determining the [jid] that is subscribing to the node are:
  /// 1. If [subscribee] is given, use that as provided.
  /// 2. If [iqFrom] was given, use the bare or full version based on bare.
  /// 3. Otherwise, use @internal [base.transport.boundJID] based on [bare].
  ///
  /// [bare] indicates if the [subscribee] is a bare or full [jid]. Defaults to
  /// `true` for a bare [JabberID].
  ///
  /// For more information, see:
  /// <https://xmpp.org/extensions/xep-0060.html#subscriber-subscribe>
  FutureOr<IQ> subscribe<T>(
    JabberID jid,
    String node, {
    Form? options,
    bool bare = true,
    String? subscribee,
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    String? sub = subscribee;
    final iq = base.makeIQSet(iqTo: jid, iqFrom: iqFrom);
    final subscribe =
        (iq['pubsub'] as PubSubStanza)['subscribe'] as PubSubSubscribe;
    subscribe['node'] = node;

    if (sub == null) {
      if (iqFrom != null) {
        if (bare) {
          sub = iqFrom.bare;
        } else {
          sub = iqFrom.toString();
        }
      } else {
        if (bare) {
          sub = base.transport.boundJID.bare;
        } else {
          sub = base.transport.boundJID.toString();
        }
      }
    }

    subscribe['jid'] = JabberID(sub);
    if (options != null) {
      ((iq['pubsub'] as PubSubStanza)['options'] as PubSubOptions).add(options);
    }

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Unsubscribes from updates from a pubsub [node].
  ///
  /// The subscriber sends an IQ-set whose __pubsub__ child contains
  /// __unsubscribe__ element that specifies the node and the subscribed JID.
  ///
  /// The rules for determining the [jid] that is unsubscribing from the node
  /// are:
  /// 1. If [subscribee] is given, use that as provided.
  /// 2. If [iqFrom] was given, use the [bare] or full version based on bare.
  /// 3. Otherwise, use [base.transport.boundJID] based on bare.
  ///
  /// [subID] is the specifiec subscription, if multiple subscriptions exist
  /// for this [jid]/[node] combination.
  ///
  /// ### Example:
  /// ```xml
  /// <iq type='set'
  ///     from='vsevex@example.com/desktop'
  ///     to='pubsub.example.com'
  ///     id='unsub1'>
  ///   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
  ///     <unsubscribe
  ///         node='someNode'
  ///         jid='francisco@example.com'/>
  ///   </pubsub>
  /// </iq>
  /// ```
  FutureOr<IQ> unsubscribe<T>(
    JabberID jid,
    String node, {
    bool bare = true,
    String? subID,
    String? subscribee,
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    String? sub = subscribee;
    final iq = base.makeIQSet(iqTo: jid, iqFrom: iqFrom);
    final unsubscribe =
        (iq['pubsub'] as PubSubStanza)['unsubscribe'] as PubSubUnsubscribe;
    unsubscribe['node'] = node;

    if (sub == null) {
      if (iqFrom != null) {
        if (bare) {
          sub = iqFrom.bare;
        } else {
          sub = iqFrom.toString();
        }
      } else {
        if (bare) {
          sub = base.transport.boundJID.bare;
        } else {
          sub = base.transport.boundJID.toString();
        }
      }
    }

    unsubscribe['jid'] = JabberID(sub);
    unsubscribe['subid'] = subID;

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Requests the contents of a [node]'s items.
  ///
  /// The desired items can be specified, or a query for the last few pubslihed
  /// items can be used.
  ///
  /// The service may use result set management (RSM) for nodes with many items,
  /// so an [iterator] can be returned if needed. Defining [maxItems] will help
  /// the service to bring items not greater than the provided [maxItems].
  /// Defaults to `null`. Means that the service will not use pagination.
  ///
  /// If [itemIDs] was provided, then the service will bring the results that
  /// corresponds to the given ID.
  ///
  /// For more information, see:
  /// <https://xmpp.org/extensions/xep-0060.html#entity-discoveritems>
  FutureOr<XMLBase?> getItems<T>(
    JabberID jid,
    String node, {
    JabberID? iqFrom,
    int? maxItems,
    bool iterator = false,
    Set<String>? itemIDs,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) async {
    final iq = base.makeIQGet(iqTo: jid, iqFrom: iqFrom);
    final items = (iq['pubsub'] as PubSubStanza)['items'] as PubSubItems;
    items['node'] = node;

    if (itemIDs != null) {
      for (final itemID in itemIDs) {
        final item = PubSubItem();
        item['id'] = itemID;
        items.add(item);
      }
    }

    if (iterator) {
      if (_rsm == null) {
        Log.instance.warning(
          'The IQ must be iterated, but Result Set Management plugin is not registered',
        );
      } else {
        _iterator ??= _rsm!
            .iterate(
              iq,
              'pubsub',
              amount: maxItems ?? 10,
              postCallback: callback,
            )
            .iterator;

        if (_iterator != null) {
          if (_iterator!.moveNext()) {
            return await _iterator!.current;
          }
        }
      }

      return null;
    } else {
      return iq.sendIQ(
        callback: callback,
        failureCallback: failureCallback,
        timeoutCallback: timeoutCallback,
        timeout: timeout,
      );
    }
  }

  /// Retrieves the content of an individual item.
  FutureOr<IQ> getItem<T>(
    JabberID jid,
    String node,
    String itemID, {
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = base.makeIQGet(iqTo: jid, iqFrom: iqFrom);

    final item = PubSubItem();
    item['id'] = itemID;

    final items = (iq['pubsub'] as PubSubStanza)['items'] as PubSubItems;
    items['node'] = node;
    items.add(item);

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Deletes a single item from a [node].
  ///
  /// To delete an item from the node, the publisher sends a retract request as
  /// shown in the following example:
  ///
  /// ```xml
  ///<iq type='set'
  ///     from='vsevex@example.com/desktop'
  ///     to='pubsub.example.com'
  ///     id='retract1'>
  ///   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
  ///     <retract node='cartNode'>
  ///       <item id='ae890ac52d0df67ed7cfdf51b644e901'/>
  ///     </retract>
  ///   </pubsub>
  /// </iq>
  /// ```
  ///
  /// If not error occurs, the service MUST delete the item.
  ///
  /// If there is a need to [notify] about item retraction, then [notify]
  /// should equal to either `true` or `1`.
  ///
  /// The rest of the parameters are related with the [IQ] stanza and each of
  /// them are responsible what to do when the server send the response. The
  /// server can send result stanza, error type stanza or the request can be
  /// timed out. [timeout] defaults to `10` seconds. If there is not any result
  /// or error from the server after the given seconds, then client stops to
  /// wait for an answer.
  FutureOr<IQ> retract<T>(
    JabberID jid,
    String node,
    String id, {
    String? notify,
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = base.makeIQSet(iqTo: jid, iqFrom: iqFrom);

    final retract = (iq['pubsub'] as PubSubStanza)['retract'] as PubSubRetract;
    retract['node'] = node;
    retract['notify'] = notify;
    (retract['item'] as PubSubItem)['id'] = id;

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Removes all items from a [node].
  ///
  /// If a service persists all published items, a node owner may want to purge
  /// the node of all published items (thus removing all items from the
  /// persistent store).
  ///
  /// ### Example:
  /// ```xml
  /// <iq type='set'
  ///     from='vsevex@example.com'
  ///     to='pubsub.example.com'
  ///     id='purge1'>
  ///   <pubsub xmlns='http://jabber.org/protocol/pubsub#owner'>
  ///     <purge node='someNode'/>
  ///   </pubsub>
  /// </iq>
  /// ```
  FutureOr<IQ> purge<T>(
    JabberID jid,
    String node, {
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = base.makeIQSet(iqTo: jid, iqFrom: iqFrom);

    ((iq['pubsub_owner'] as PubSubOwnerStanza)['purge']
        as PubSubOwnerPurge)['node'] = node;

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Retrieves all subscriptions for all [node]s.
  ///
  /// An entity may want to query the serveice to retrieve its subscriptions for
  /// all nodes at the service.
  ///
  /// If the service returns a list of subscriptions, it MUST return all
  /// subscriptions for all JIDs that match the bare JID (<vsevex@example.com>
  /// or <example.com>) portion of the 'from' attribute on the request.
  ///
  /// ### Example:
  /// ```xml
  /// <iq type='get'
  ///     from='vsevex@example.com/mobile'
  ///     to='pubsub.example.com'
  ///     id='subscriptions1'>
  ///   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
  ///     <subscriptions/>
  ///   </pubsub>
  /// </iq>
  /// ```
  FutureOr<IQ> getSubscriptions<T>(
    JabberID jid, {
    String? node,
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = base.makeIQGet(iqTo: jid, iqFrom: iqFrom);
    ((iq['pubsub'] as PubSubStanza)['subscriptions']
        as PubSubSubscriptions)['node'] = node;
    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Retrieves its affiliations for all [node]s at the service.
  ///
  /// An entity may want to query the service to retrieve its affiliations for
  /// all nodes at the service, or query a specific node for its affiliation
  /// with that node.
  ///
  /// ### Example:
  /// ```xml
  /// <iq type='get'
  ///     from='vsevex@example.com'
  ///     to='pubsub.example.com'
  ///     id='affil1'>
  ///   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
  ///     <affiliations/>
  ///   </pubsub>
  /// </iq>
  /// ```
  ///
  /// see: <https://xmpp.org/extensions/xep-0060.html#entity-affiliations>
  FutureOr<IQ> getAffiliations<T>(
    JabberID jid, {
    String? node,
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = base.makeIQGet(iqTo: jid, iqFrom: iqFrom);
    ((iq['pubsub'] as PubSubStanza)['affiliations']
        as PubSubAffiliations)['node'] = node;
    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Requests the subscription options.
  ///
  /// ### Example:
  /// ```xml
  /// <iq type='get'
  ///     from='alyosha@example.com'
  ///     to='pubsub.example.com'
  ///     id='options1'>
  ///   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
  ///     <options node='someNode' jid='alyosha@example.com'/>
  ///   </pubsub>
  /// </iq>
  /// ```
  ///
  /// see:
  /// <https://xmpp.org/extensions/xep-0060.html#subscriber-configure-request>
  FutureOr<IQ> getSubscriptionOptions<T>(
    JabberID jid, {
    String? node,
    JabberID? userJID,
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = base.makeIQGet(iqTo: jid, iqFrom: iqFrom);
    final pubsub = iq['pubsub'] as PubSubStanza;
    if (userJID == null) {
      (pubsub['default'] as PubSubDefault)['node'] = node;
    } else {
      final options = pubsub['options'] as PubSubOptions;
      options['node'] = node;
      options['jid'] = userJID;
    }

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Sets the subscription options.
  ///
  /// ### Example:
  /// ```xml
  /// <iq type='set'
  ///     from='vsevex@example.com'
  ///     to='pubsub.example.com'
  ///     id='options2'>
  ///   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
  ///     <options node='someNode' jid='vsevex@example.com'>
  ///      <x xmlns='jabber:x:data' type='submit'>
  ///         <field var='FORM_TYPE' type='hidden'>
  ///           <value>http://jabber.org/protocol/pubsub#subscribe_options</value>
  ///         </field>
  ///         <field var='pubsub#deliver'><value>1</value></field>
  ///         <field var='pubsub#digest'><value>0</value></field>
  ///         <field var='pubsub#include_body'><value>false</value></field>
  ///         <field var='pubsub#show-values'>
  ///           <value>chat</value>
  ///           <value>online</value>
  ///           <value>away</value>
  ///         </field>
  ///       </x>
  ///     </options>
  ///   </pubsub>
  /// </iq>
  /// ```
  /// see:
  /// <https://xmpp.org/extensions/xep-0060.html#subscriber-configure-submit>
  FutureOr<IQ> setSubscriptionOptions<T>(
    JabberID jid,
    String node,
    JabberID userJID,
    Form options, {
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = base.makeIQSet(iqTo: jid, iqFrom: iqFrom);
    final pubsub = iq['pubsub'] as PubSubStanza;

    final options = pubsub['options'] as PubSubOptions;
    options['node'] = node;
    options['jid'] = userJID;
    options.add(options);

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Discovers the nodes provided by a PubSub service, using
  /// [ServiceDiscovery].
  ///
  /// For parameters explanation, please refer to [ServiceDiscovery]'s
  /// [getItems] method.
  Future<XMLBase?> getNodes({
    JabberID? jid,
    String? node,
    JabberID? iqFrom,
    bool local = false,
    bool iterator = false,
  }) {
    if (_disco != null) {
      return _disco!.getItems(
        jid: jid,
        node: node,
        iqFrom: iqFrom,
        local: local,
        iterator: iterator,
      );
    } else {
      Log.instance
          .warning("Nodes' discovery requires Service Discovery plugin");
      return Future.value();
    }
  }

  /// Retrieves the configuration for a [node], or the pubsub service's
  /// default configuration for new nodes.
  FutureOr<IQ> getNodeConfig<T>(
    JabberID jid, {
    String? node,
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = base.makeIQGet(iqTo: jid, iqFrom: iqFrom);
    if (node == null) {
      (iq['pubsub_owner'] as PubSubOwnerStanza).enable('default');
    } else {
      ((iq['pubsub_owner'] as PubSubOwnerStanza)['configure']
          as PubSubOwnerConfigure)['node'] = node;
    }

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Sets a [config] to the [node].
  FutureOr<IQ> setNodeConfig<T>(
    JabberID jid,
    String node,
    Form config, {
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = base.makeIQSet(iqTo: jid, iqFrom: iqFrom);
    ((iq['pubsub_owner'] as PubSubOwnerStanza)['delete']
        as PubSubOwnerDelete)['node'] = node;
    ((iq['pubsub_owner'] as PubSubOwnerStanza)['configure']
            as PubSubOwnerConfigure)
        .add(config);

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Retrieves the subscriptions associated with a given [node].
  FutureOr<IQ> getNodeSubscriptions<T>(
    JabberID jid,
    String node, {
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = base.makeIQGet(iqTo: jid, iqFrom: iqFrom);
    ((iq['pubsub_owner'] as PubSubOwnerStanza)['subscriptions']
        as PubSubOwnerSubscriptions)['node'] = node;

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Retrieves the affiliations associated with a given [node].
  FutureOr<IQ> getNodeAffiliations<T>(
    JabberID jid,
    String node, {
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = base.makeIQGet(iqTo: jid, iqFrom: iqFrom);
    ((iq['pubsub_owner'] as PubSubOwnerStanza)['affiliations']
        as PubSubOwnerAffiliations)['node'] = node;

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Deletes a pubsub [node].
  FutureOr<IQ> deleteNode<T>(
    JabberID jid,
    String node,
    Form config, {
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = base.makeIQSet(iqTo: jid, iqFrom: iqFrom);
    ((iq['pubsub_owner'] as PubSubOwnerStanza)['configure']
        as PubSubOwnerConfigure)['node'] = node;
    ((iq['pubsub_owner'] as PubSubOwnerStanza)['configure']
            as PubSubOwnerConfigure)
        .add(config);

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Retrieves the ItemIDs hosted by a given node, using [ServiceDiscovery].
  Future<XMLBase?> getItemIDs<T>(
    JabberID jid,
    String node, {
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    if (_disco != null) {
      return _disco!.getItems<T>(
        jid: jid,
        node: node,
        iqFrom: iqFrom,
        callback: callback,
        failureCallback: failureCallback,
        timeoutCallback: timeoutCallback,
        timeout: timeout,
      );
    } else {
      Log.instance
          .warning("ItemIDs' discovery requires Service Discovery plugin");
      return Future.value();
    }
  }

  FutureOr<IQ> modifyAffiliations<T>(
    JabberID jid,
    String node, {
    Map<JabberID, String>? affiliations,
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = base.makeIQSet(iqTo: jid, iqFrom: iqFrom);
    ((iq['pubsub_owner'] as PubSubOwnerStanza)['affiliations']
        as PubSubOwnerAffiliations)['node'] = node;

    affiliations ??= <JabberID, String>{};

    for (final affiliation in affiliations.entries) {
      final aff = PubSubOwnerAffiliation();
      aff['jid'] = affiliation.key;
      aff['affiliation'] = affiliation.value;
      ((iq['pubsub_owner'] as PubSubOwnerStanza)['affiliations']
              as PubSubOwnerAffiliations)
          .add(aff);
    }

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  FutureOr<IQ> modifySubscriptions<T>(
    JabberID jid,
    String node, {
    Map<JabberID, String>? subscriptions,
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = base.makeIQSet(iqTo: jid, iqFrom: iqFrom);
    ((iq['pubsub_owner'] as PubSubOwnerStanza)['subscriptions']
        as PubSubOwnerSubscriptions)['node'] = node;

    subscriptions = <JabberID, String>{};

    for (final subscription in subscriptions.entries) {
      final sub = PubSubOwnerSubscription();
      sub['jid'] = subscription.key;
      sub['subscription'] = subscription.value;
      ((iq['pubsub_owner'] as PubSubOwnerStanza)['subscriptions']
              as PubSubOwnerSubscriptions)
          .add(sub);
    }

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  @override
  void pluginEnd() {
    base.transport
      ..removeHandler('Pubsub Items')
      ..removeHandler('Pubsub Subscription')
      ..removeHandler('Pubsub Configuration')
      ..removeHandler('Pubsub Delete')
      ..removeHandler('Pubsub Purge');
  }

  /// Do not implement.
  @override
  void sessionBind(String? jid) {}
}
