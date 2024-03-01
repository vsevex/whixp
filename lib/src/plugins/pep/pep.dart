import 'dart:async';

import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/plugins/plugins.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stream/base.dart';

/// Personal eventing provides a way for a Jabber/XMPP user to send updates or
/// "events" to other users, who are typically contacts in the user's roster.
///
/// An event can be anything that a user wants to make known to other people,
/// such as those described in User Geolocation (XEP-0080), User Mood
/// (XEP-0107), User Activity (XEP-0108), and User Tune (XEP-0118). While the
/// XMPP Publish-Subscribe (XEP-0060) extension ("pubsub") can be used to
/// broadcast such events associated, the full pubsub protocol is often
/// thought of as complicated and therefore has not been widely implemented.
///
/// see <https://xmpp.org/extensions/xep-0163.html>
class PEP extends PluginBase {
  PEP()
      : super(
          'PEP',
          description: 'XEP-0163: Personal Eventing Protocol',
          dependencies: <String>{'disco', 'pubsub'},
        );

  late final PubSub _pubsub;

  /// If [PubSub] stanza is not registered by user, do not hesitate to register
  /// the corresponding plugin, 'cause [PEP] requires initialization of the
  /// [PubSub].
  @override
  void pluginInitialize() {
    if (base.getPluginInstance<PubSub>('pubsub') == null) {
      _pubsub = PubSub();
      base.registerPlugin(_pubsub);
    }
  }

  /// Setups and configures events and registers [stanza] for the given PEP
  /// stanza.
  ///
  /// * Adds service discovery feature for the PEP content.
  /// * Registers discovery interest in the PEP content.
  /// * Maps events from the PEP content's `namespace` to the given [name].
  void registerPEP(String name, XMLBase stanza) {
    stanza.registerPlugin(PubSubEventItem());

    addInterest([stanza.namespace]);

    final disco = base.getPluginInstance<ServiceDiscovery>('disco');
    if (disco != null) {
      disco.addFeature(stanza.namespace);
    }

    final pubsub = base.getPluginInstance<PubSub>('pubsub');
    if (pubsub != null) {
      pubsub.mapNodeEvent(stanza.namespace, name);
    }
  }

  /// Marks an interest in a PEP subscription by including a [ServiceDiscovery]
  /// feature with the '+notify' extension.
  ///
  /// [namespaces] is the [List] of namespaces to register interests, such as
  /// 'http://jabber.org/protocol/tune'.
  void addInterest(List<String> namespaces, {JabberID? jid}) {
    for (final namespace in namespaces) {
      final disco = base.getPluginInstance<ServiceDiscovery>('disco');
      if (disco != null) {
        disco.addFeature('$namespace+notify', jid: jid);
      }
    }
  }

  /// Marks an interest in a PEP subscription by including a [ServiceDiscovery]
  /// feature with the '+notify' extension.
  void removeInterest(List<String> namespaces, {JabberID? jid}) {
    for (final namespace in namespaces) {
      final disco = base.getPluginInstance<ServiceDiscovery>('disco');
      if (disco != null) {
        disco.removeFeature('$namespace+notify', jid: jid);
      }
    }
  }

  /// Publishes a [PEP] update.
  ///
  /// This is just a thin wrapper around the [PubSub]'s [publish] method to set
  /// the defaults expected by [PEP].
  FutureOr<IQ> publish<T>(
    JabberID jid,
    XMLBase stanza, {
    String? node,
    String? id,
    Form? options,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    node ??= stanza.namespace;
    id ??= 'current';

    return _pubsub.publish(
      jid,
      node,
      id: id,
      iqFrom: jid,
      payload: stanza.element,
      options: options,
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Do not implement.
  @override
  void sessionBind(String? jid) {}

  /// Do not implement.
  @override
  void pluginEnd() {}
}
