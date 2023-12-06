import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/jid/jid.dart';
import 'package:echox/src/plugins/base.dart';
import 'package:echox/src/stream/base.dart';
import 'package:echox/src/transport/transport.dart';
import 'package:meta/meta.dart';

abstract class WhixpBase {
  WhixpBase({
    String? host,
    int? port,
    String jabberID = '',
    String? dnsService,
    String? defaultNamespace,
    bool useTLS = false,
  }) {
    streamNamespace = Echotils.getNamespace('JABBER_STREAM');
    this.defaultNamespace = defaultNamespace ?? Echotils.getNamespace('CLIENT');
    _requestedJID = JabberIDTemp(jabberID);
    boundJID = JabberIDTemp(jabberID);
    pluginManager = PluginManager();

    /// Assignee for later.
    String address;

    /// Check if this class is not used for component initialization, and try
    /// to point [host] and [port] properly.
    if (!_isComponent && host == null) {
      address = boundJID.host;
      port = 5222;
    } else {
      address = host!;
      dnsService = null;
    }

    /// Declare [Transport] with the passed params.
    transport = Transport(
      address,
      port: port,
      isComponent: _isComponent,
      dnsService: dnsService,
      useTLS: useTLS,
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
  }
  late final Transport transport;

  /// Late final initialization of stream namespace.
  late final String streamNamespace;

  /// Late final initialization of default namespace.
  late final String defaultNamespace;

  /// The JabberID (JID) requested for this connection.
  late final JabberIDTemp _requestedJID;

  /// The JabberID (JID) used by this connection, as set after session binding.
  ///
  /// This may even be a different bare JID than what was requested.
  late final JabberIDTemp boundJID;

  /// The maximum number of consecutive `see-other-host` redirections that will
  /// be followed before quitting.
  final _maxRedirects = 5;

  /// The distinction between clients and components can be important, primarily
  /// for choosing how to handle the `to` and `from` JIDs of stanzas.
  final bool _isComponent = false;

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

  void registerPlugin(String name, PluginBase plugin) {
    if (!pluginManager.registered(name)) {
      pluginManager.register(name, plugin);
    }
    pluginManager.enable(name);
  }
}
