import 'dart:async';

import 'package:dartz/dartz.dart';

import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/jid/jid.dart';
import 'package:echox/src/plugins/base.dart';
import 'package:echox/src/stanza/iq.dart';
import 'package:echox/src/stanza/presence.dart';
import 'package:echox/src/stream/base.dart';
import 'package:echox/src/transport.dart';

import 'package:meta/meta.dart';

abstract class WhixpBase {
  WhixpBase({
    String? host,
    int port = 5222,
    String jabberID = '',
    String? defaultNamespace,
    bool useIPv6 = false,
    bool useTLS = false,
    bool disableStartTLS = false,
    List<Tuple2<String, String?>>? certs,
    int connectionTimeout = 3000,
  }) {
    streamNamespace = Echotils.getNamespace('JABBER_STREAM');
    this.defaultNamespace = defaultNamespace ?? Echotils.getNamespace('CLIENT');
    requestedJID = JabberID(jabberID);
    final boundJID = JabberID(jabberID);
    pluginManager = PluginManager();

    /// Assignee for later.
    late String address;
    late String? dnsService;

    if (!_isComponent) {
      /// Check if this class is not used for component initialization, and try
      /// to point [host] and [port] properly.
      if (host == null) {
        address = boundJID.host;

        if (useTLS) {
          dnsService = 'xmpps-client';
        } else {
          dnsService = 'xmpp-client';
        }
      } else {
        address = host;
        dnsService = null;
      }
    }

    /// Declare [Transport] with the passed params.
    transport = Transport(
      address,
      port: port,
      useIPv6: useIPv6,
      disableStartTLS: disableStartTLS,
      isComponent: _isComponent,
      dnsService: dnsService,
      useTLS: useTLS,
      caCerts: certs,
      boundJID: boundJID,
      connectionTimeout: connectionTimeout,
      startStreamHandler: (attributes, transport) {
        String streamVersion = '';

        for (final attribute in attributes) {
          if (attribute.qualifiedName == 'version') {
            streamVersion = attribute.value;
          } else if (attribute.qualifiedName == 'xml:lang') {
            transport.peerDefaultLanguage = attribute.value;
          }
        }

        if (!_isComponent && streamVersion.isEmpty) {
          transport.emit('legacyProtocol');
        }
      },
    );

    transport.registerStanza(IQ(generateID: false));
  }
  late final Transport transport;

  /// Late final initialization of stream namespace.
  late final String streamNamespace;

  /// Late final initialization of default namespace.
  late final String defaultNamespace;

  /// The JabberID (JID) requested for this connection.
  late final JabberID requestedJID;

  /// The maximum number of consecutive `see-other-host` redirections that will
  /// be followed before quitting.
  final _maxRedirects = 5;

  /// The distinction between clients and components can be important, primarily
  /// for choosing how to handle the `to` and `from` JIDs of stanzas.
  final bool _isComponent = false;

  Map<String, String> credentials = <String, String>{};

  @internal
  late final PluginManager pluginManager;

  final features = <String>{};

  final streamFeatureHandlers =
      <String, Tuple2<FutureOr<dynamic> Function(StanzaBase stanza), bool>>{};

  final streamFeatureOrder = <Tuple2<int, String>>[];

  void registerFeature(
    String name,
    FutureOr<dynamic> Function(StanzaBase stanza) handler, {
    bool restart = false,
    int order = 5000,
  }) {
    streamFeatureHandlers[name] = Tuple2(handler, restart);
    streamFeatureOrder.add(Tuple2(order, name));
    streamFeatureOrder.sort((a, b) => a.value1.compareTo(b.value1));
  }

  void sendPresence() {
    final presence = makePresence();
    return presence.send();
  }

  Presence makePresence({
    String? presenceShow,
    String? presenceStatus,
    String? presencePriority,
    String? presenceType,
    String? presenceFrom,
    String? stanzaType,
    String? stanzaTo,
    String? stanzaFrom,
    String? presenceNick,
  }) {
    final presence = _presence(
      stanzaType: stanzaType,
      stanzaTo: stanzaTo,
      stanzaFrom: stanzaFrom,
    );
    if (presenceShow != null) {
      presence['type'] = presenceShow;
    }
    if (presenceFrom != null && transport.isComponent) {
      presence['from'] = transport.boundJID.full;
    }
    presence['priority'] = presencePriority;
    presence['status'] = presenceStatus;
    presence['nick'] = presenceNick;
    return presence;
  }

  Presence _presence({
    String? stanzaType,
    String? stanzaTo,
    String? stanzaFrom,
  }) {
    final presence = Presence(
      transport: transport,
      stanzaType: stanzaType,
      stanzaTo: stanzaTo,
      stanzaFrom: stanzaFrom,
    );
    presence['lang'] = transport.defaultLanguage;
    return presence;
  }

  void registerPlugin(String name, PluginBase plugin) {
    if (!pluginManager.registered(name)) {
      pluginManager.register(name, plugin);
    }
    pluginManager.enable(name);
  }
}
