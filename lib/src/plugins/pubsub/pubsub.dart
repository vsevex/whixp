import 'dart:async' as async;

import 'package:whixp/src/_static.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/plugins/plugins.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/message.dart';
import 'package:whixp/src/stanza/node.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/transport.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

part 'pep.dart';
part 'stanza.dart';
part 'vcard4.dart';

enum PubSubNodeType { leaf, collection }

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
class PubSub {
  /// An empty constructor, will not be used.
  const PubSub();

  static void initialize() => Transport.instance().registerHandler(
        Handler(
          'PubSub Event items',
          (packet) => _handleEventItems(packet as Message),
        )..descendant('message/event/items'),
      );

  static void _handleEventItems(Message message) {
    final items = message.get<PubSubEvent>().first.items;
    if (items?.isEmpty ?? true) return;

    for (final item in items!.entries) {
      final payload = item.value.last.payload;
      if (payload != null) {
        Transport.instance()
            .emit<Stanza>(item.key, data: item.value.last.payload);
      }
    }
  }

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
  static async.FutureOr<IQ> createNode<T>(
    JabberID jid, {
    String? node,
    Form? config,
    PubSubNodeType? nodeType,
    async.FutureOr<T> Function(IQ iq)? callback,
    async.FutureOr<void> Function(ErrorStanza error)? failureCallback,
    async.FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = IQ(generateID: true)
      ..to = jid
      ..type = iqTypeSet;

    final pubsub =
        PubSubStanza(nodes: [Node('create')..addAttribute('node', node)]);

    if (config != null) {
      const formType = 'http://jabber.org/protocol/pubsub#node_config';
      config.fields.add(
        Field(
          variable: 'FORM_TYPE',
          type: FieldType.hidden,
          values: [formType],
        ),
      );
      if (nodeType != null) {
        config.fields
            .add(Field(variable: 'pubsub#node_type', values: [nodeType.name]));
      }
      pubsub.nodes.add(Node('configure')..addStanza(config));
    }

    iq.payload = pubsub;

    return iq.send(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Deletes a pubsub [node].
  static async.FutureOr<IQ> deleteNode<T>(
    JabberID jid,
    String node, {
    async.FutureOr<T> Function(IQ iq)? callback,
    async.FutureOr<void> Function(ErrorStanza error)? failureCallback,
    async.FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = IQ(generateID: true)
      ..to = jid
      ..type = iqTypeGet;
    final pubsub = PubSubStanza(
      owner: true,
      nodes: [Node('delete')..addAttribute('node', node)],
    );

    iq.payload = pubsub;

    return iq.send(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Retrieves the configuration for a [node], or the pubsub service's
  /// default configuration for new nodes.
  static async.FutureOr<Form?> getNodeConfig<T>(
    JabberID jid, {
    String? node,
    async.FutureOr<T> Function(IQ iq)? callback,
    async.FutureOr<void> Function(ErrorStanza error)? failureCallback,
    async.FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) async {
    final iq = IQ(generateID: true)
      ..to = jid
      ..type = iqTypeGet;
    final pubsub = PubSubStanza(owner: true);
    if (node == null) {
      pubsub.addNode(Node('default'));
    } else {
      pubsub.addNode(Node('configure')..addAttribute('node', node));
    }

    iq.payload = pubsub;

    final result = await iq.send(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );

    if (result.payload == null) return null;
    final owner = result.payload! as PubSubStanza;

    return owner.configuration!.get<Form>('dataforms').first;
  }

  /// Sets a [config] to the [node].
  static async.FutureOr<IQ> setNodeConfig<T>(
    JabberID jid,
    String node,
    Form config, {
    async.FutureOr<T> Function(IQ iq)? callback,
    async.FutureOr<void> Function(ErrorStanza error)? failureCallback,
    async.FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    /// Check if the type of the form is `submit`, if not, try to set type to
    /// [FormType.submit].
    if (config.type != FormType.submit) {
      config.type = FormType.submit;
    }
    final iq = IQ(generateID: true)
      ..to = jid
      ..type = iqTypeSet
      ..payload = PubSubStanza(
        owner: true,
        configuration: Node('configure')
          ..addAttribute('node', node)
          ..addStanza(config),
      );

    return iq.send(
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
  static async.FutureOr<IQ> subscribe<T>(
    JabberID jid,
    String node, {
    Form? options,
    JabberID? iqFrom,
    bool bare = true,
    String? subscribee,
    async.FutureOr<T> Function(IQ iq)? callback,
    async.FutureOr<void> Function(ErrorStanza error)? failureCallback,
    async.FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    String? sub = subscribee;
    final iq = IQ(generateID: true)
      ..to = jid
      ..type = iqTypeSet;

    final subscribe = Node('subscribe')..addAttribute('node', node);

    if (sub == null) {
      if (iqFrom != null) {
        if (bare) {
          sub = iqFrom.bare;
        } else {
          sub = iqFrom.toString();
        }
      } else {
        if (bare) {
          sub = Transport.instance().boundJID?.bare;
        } else {
          sub = Transport.instance().boundJID?.toString();
        }
      }
    }

    subscribe.addAttribute('jid', sub);
    final pubsub = PubSubStanza(nodes: [subscribe]);
    if (options != null) {
      pubsub.addNode(Node('options')..addStanza(options));
    }
    iq.payload = pubsub;

    return iq.send(
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
  static async.FutureOr<IQ> unsubscribe<T>(
    JabberID jid,
    String node, {
    bool bare = true,
    String? subID,
    String? subscribee,
    async.FutureOr<T> Function(IQ iq)? callback,
    async.FutureOr<void> Function(ErrorStanza error)? failureCallback,
    async.FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    String? sub = subscribee;
    final iq = IQ(generateID: true)
      ..to = jid
      ..type = iqTypeSet;
    final unsubscribe = Node('unsubscribe')..addAttribute('node', node);

    if (sub == null) {
      if (bare) {
        sub = Transport.instance().boundJID?.bare;
      } else {
        sub = Transport.instance().boundJID?.toString();
      }
    }

    unsubscribe
      ..addAttribute('jid', sub)
      ..addAttribute('subid', subID);

    iq.payload = PubSubStanza(nodes: [unsubscribe]);

    return iq.send(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Retrieves the subscriptions associated with a given [node].
  static async.FutureOr<IQ> getNodeSubscriptions<T>(
    JabberID jid,
    String node, {
    async.FutureOr<T> Function(IQ iq)? callback,
    async.FutureOr<void> Function(ErrorStanza error)? failureCallback,
    async.FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = IQ(generateID: true)
      ..to = jid
      ..type = iqTypeGet
      ..payload = PubSubStanza(
        owner: true,
        nodes: [Node('subscriptions')..addAttribute('node', node)],
      );

    return iq.send(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Publishes the given [vcard] to the given [jid].
  static async.FutureOr<IQ> publishVCard<T>(
    VCard4 vcard, {
    async.FutureOr<T> Function(IQ iq)? callback,
    async.FutureOr<void> Function(ErrorStanza error)? failureCallback,
    async.FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = IQ(generateID: true)
      ..type = iqTypeSet
      ..payload = PubSubStanza(
        publish: _Publish(
          node: 'urn:xmpp:vcard4',
          item: _Item(payload: vcard),
        ),
      );

    return iq.send(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  static async.FutureOr<IQ> retractVCard<T>(
    String id, {
    async.FutureOr<T> Function(IQ iq)? callback,
    async.FutureOr<void> Function(ErrorStanza error)? failureCallback,
    async.FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final iq = IQ(generateID: true)
      ..type = iqTypeSet
      ..payload = PubSubStanza(
        retract: _Retract(
          node: 'urn:xmpp:vcard4',
          item: _Item(id: id),
        ),
      );

    return iq.send(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Retrieves vCard information of the given [jid].
  ///
  /// Returns all time published [VCard4] items. For last item in the server,
  /// use .last.payload getter.
  static async.FutureOr<List<_Item?>> retrieveVCard<T>(
    JabberID jid, {
    async.FutureOr<T> Function(IQ iq)? callback,
    async.FutureOr<void> Function(ErrorStanza error)? failureCallback,
    async.FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) async {
    final iq = IQ(generateID: true)
      ..to = jid
      ..type = iqTypeGet
      ..payload = PubSubStanza(
        nodes: [Node('items')..addAttribute('node', 'urn:xmpp:vcard4')],
      );

    final result = await iq.send(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
    if (result.payload == null) return [];

    final pubsub = result.payload! as PubSubStanza;
    final items = pubsub.items['urn:xmpp:vcard4'];
    if (items?.isEmpty ?? true) return [];

    return items!;
  }

  /// Subscribes to the vCard updates of the given [jid].
  static async.FutureOr<IQ> subscribeToVCardUpdates<T>(
    JabberID jid, {
    async.FutureOr<T> Function(IQ iq)? callback,
    async.FutureOr<void> Function(ErrorStanza error)? failureCallback,
    async.FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) =>
      subscribe(
        jid,
        'urn:xmpp:vcard4',
        callback: callback,
        failureCallback: failureCallback,
        timeoutCallback: timeoutCallback,
        timeout: timeout,
      );

  /// Unsubscribes the vCard updates from the given [jid].
  static async.FutureOr<IQ> unsubscribeVCardUpdates<T>(
    JabberID jid, {
    async.FutureOr<T> Function(IQ iq)? callback,
    async.FutureOr<void> Function(ErrorStanza error)? failureCallback,
    async.FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) =>
      unsubscribe(
        jid,
        'urn:xmpp:vcard4',
        callback: callback,
        failureCallback: failureCallback,
        timeoutCallback: timeoutCallback,
        timeout: timeout,
      );
}
