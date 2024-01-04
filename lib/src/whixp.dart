import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:echox/echox.dart';

import 'package:echox/src/handler/callback.dart';
import 'package:echox/src/plugins/base.dart';
import 'package:echox/src/plugins/features.dart';
import 'package:echox/src/roster/manager.dart' as roster;
import 'package:echox/src/stanza/error.dart';
import 'package:echox/src/stanza/features.dart';
import 'package:echox/src/stanza/roster.dart';
import 'package:echox/src/stream/base.dart';
import 'package:echox/src/stream/matcher/xpath.dart';
import 'package:echox/src/transport.dart';

part 'plugins/starttls/starttls.dart';
part 'plugins/starttls/stanza.dart';
part 'client.dart';

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
    int maxReconnectionAttempt = 3,
    int maxRedirects = 5,
  }) {
    streamNamespace = Echotils.getNamespace('JABBER_STREAM');
    this.defaultNamespace = defaultNamespace ?? Echotils.getNamespace('CLIENT');
    requestedJID = JabberID(jabberID);
    final boundJID = JabberID(jabberID);
    _pluginManager = PluginManager();
    _maxRedirects = maxRedirects;

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
      maxReconnectionAttempt: maxReconnectionAttempt,
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

    transport
      ..registerStanza(IQ(generateID: false))
      ..registerStanza(Presence())
      ..registerStanza(Message(includeNamespace: true))
      ..registerStanza(StreamError())
      ..registerHandler(
        CallbackHandler(
          'Presence',
          _handlePresence,
          matcher: XPathMatcher('<presence xmlns="${this.defaultNamespace}"/>'),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'IM',
          _handleMessage,
          matcher: XPathMatcher('<message xmlns="${this.defaultNamespace}"/>'),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'IM',
          _handleMessage,
          matcher: XPathMatcher('<body xmlns="${this.defaultNamespace}"/>'),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'Stream Error',
          _handleStreamError,
          matcher: XPathMatcher('<error xmlns="$streamNamespace"/>'),
        ),
      );

    _roster = roster.RosterManager(this);
    _roster.add(boundJID.toString());

    _clientRoster = _roster[boundJID.toString()] as roster.RosterNode;

    transport
      ..addEventHandler<Presence>(
        'presenceDnd',
        (presence) => _handleAvailable(presence!),
      )
      ..addEventHandler<Presence>(
        'presenceXa',
        (presence) => _handleAvailable(presence!),
      )
      ..addEventHandler<Presence>(
        'presenceChat',
        (presence) => _handleAvailable(presence!),
      )
      ..addEventHandler<Presence>(
        'presenceAway',
        (presence) => _handleAvailable(presence!),
      )
      ..addEventHandler<Presence>(
        'presenceAvailable',
        (presence) => _handleAvailable(presence!),
      )
      ..addEventHandler<Presence>(
        'presenceUnavailable',
        (presence) => _handleUnavailable(presence!),
      )
      ..addEventHandler<Presence>(
        'presenceSubscribe',
        (presence) => _handleSubscribe(presence!),
      )
      ..addEventHandler<Presence>(
        'presenceSubscribed',
        (presence) => _handleSubscribed(presence!),
      )
      ..addEventHandler<Presence>(
        'presenceUnsubscribe',
        (presence) => _handleUnsubscribe(presence!),
      )
      ..addEventHandler<Presence>(
        'presenceUnsubscribed',
        (presence) => _handleUnsubscribed(presence!),
      )
      ..addEventHandler<Presence>(
        'rosterSubscriptionRequest',
        (presence) => _handleNewSubscription(presence!),
      );
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
  late final int _maxRedirects;

  final saslData = <String, dynamic>{};

  /// The distinction between clients and components can be important, primarily
  /// for choosing how to handle the `to` and `from` JIDs of stanzas.
  final bool _isComponent = false;

  Map<String, String> credentials = <String, String>{};

  late final PluginManager _pluginManager;

  late final roster.RosterManager _roster;
  late roster.RosterNode _clientRoster;

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

  void sendPresence({String? presenceFrom, String? prsenceTo}) {
    final presence = makePresence(
      presenceFrom: presenceFrom,
    );
    return presence.send();
  }

  Presence makePresence({
    String? presenceShow,
    String? presenceStatus,
    String? presencePriority,
    String? presenceTo,
    String? presenceFrom,
    String? presenceType,
    String? presenceNick,
  }) {
    final presence = _presence(
      stanzaType: presenceType,
      stanzaTo: presenceTo,
      stanzaFrom: presenceFrom,
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

  void getRoster() {
    final iq = IQ(transport: transport);
    iq['type'] = 'get';
    iq.registerPlugin(Roster());
    iq.enable('roster');

    if (features.contains('rosterver')) {
      (iq['roster'] as XMLBase)['ver'] = _clientRoster.version;
    }

    iq.sendIQ(
      callback: (stanza) =>
          transport.emit<StanzaBase>('rosterUpdate', data: stanza),
    );
  }

  void registerPlugin(String name, PluginBase plugin) {
    if (!_pluginManager.registered(name)) {
      _pluginManager.register(name, plugin);
    }
    _pluginManager.enable(name);
  }

  void _handleMessage(StanzaBase message) {
    final to = message['to'] as String;
    if (to.isNotEmpty) {
      if (!transport.isComponent && JabberID(to).bare.isNotEmpty) {
        message['to'] = transport.boundJID.toString();
      }
    }
    transport.emit<Message>('message', data: Message(element: message.element));
  }

  void _handlePresence(StanzaBase stanza) {
    final presence = Presence(element: stanza.element);

    if (((_roster[presence['from'] as String]) as roster.RosterNode)
        .ignoreUpdates) {
      return;
    }

    if (!_isComponent && JabberID(presence['to'] as String).bare.isNotEmpty) {
      presence['to'] = transport.boundJID.toString();
    }

    transport.emit<Presence>('presence', data: presence);
    transport.emit<Presence>(
      'presence${(presence['type'] as String).capitalize()}',
      data: presence,
    );

    if ({'subscribe', 'subscribed', 'unsubscribe', 'unsubscribed'}
        .contains(presence['type'])) {
      transport.emit<Presence>('changedSubscription', data: presence);
      return;
    } else if (!{'available', 'unavailable'}.contains(presence['type'])) {
      return;
    }
  }

  void _handleAvailable(Presence presence) {
    ((_roster[presence['to'] as String] as roster
            .RosterNode)[presence['from'] as String] as roster.RosterItem)
        .handleAvailable(presence);
  }

  void _handleUnavailable(Presence presence) {
    ((_roster[presence['to'] as String] as roster
            .RosterNode)[presence['from'] as String] as roster.RosterItem)
        .handleUnavailable(presence);
  }

  void _handleSubscribe(Presence presence) {
    ((_roster[presence['to'] as String] as roster
            .RosterNode)[presence['from'] as String] as roster.RosterItem)
        .handleSubscribe(presence);
  }

  void _handleSubscribed(Presence presence) {
    ((_roster[presence['to'] as String] as roster
            .RosterNode)[presence['from'] as String] as roster.RosterItem)
        .handleSubscribed(presence);
  }

  void _handleUnsubscribe(Presence presence) {
    ((_roster[presence['to'] as String] as roster
            .RosterNode)[presence['from'] as String] as roster.RosterItem)
        .handleUnsubscribe(presence);
  }

  void _handleUnsubscribed(Presence presence) {
    ((_roster[presence['to'] as String] as roster
            .RosterNode)[presence['from'] as String] as roster.RosterItem)
        .handleUnsubscribed(presence);
  }

  void _handleNewSubscription(Presence presence) {
    final rost = _roster[presence['to'] as String] as roster.RosterNode;
    final rosterItem = rost[presence['from'] as String] as roster.RosterItem;
    if (rosterItem['whitelisted'] as bool) {
      rosterItem.authorize();
      if (rost.autoAuthorize) {
        rosterItem.subscribe();
      }
    } else if (rost.autoAuthorize) {
      rosterItem.authorize();
      if (rost.autoSubscribe) {
        rosterItem.subscribe();
      }
    } else if (!rost.autoAuthorize) {
      rosterItem.unauthorize();
    }
  }

  void _handleStreamError(StanzaBase error) {
    error.registerPlugin(StreamError());
    error.enable('error');
    transport.emit<StanzaBase>('streamError', data: error);

    if (error['condition'] == 'see-other-host') {
      final otherHost = error['see-other-host'] as String?;
      if (otherHost == null || otherHost.isEmpty) {
        print('no other host specified');
        return;
      }

      transport.handleStreamError(otherHost);
    }
  }

  String get password => credentials['password']!;
}

extension StringExtension on String {
  String capitalize() =>
      '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
}
