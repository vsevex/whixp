import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:meta/meta.dart';

import 'package:whixp/src/exception.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/plugins/features.dart';
import 'package:whixp/src/roster/manager.dart' as roster;
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/features.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/message.dart';
import 'package:whixp/src/stanza/presence.dart';
import 'package:whixp/src/stanza/roster.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/stream/matcher/matcher.dart';
import 'package:whixp/src/transport.dart';
import 'package:whixp/src/utils/utils.dart';

part 'client.dart';

abstract class WhixpBase {
  /// Adapts the generic [Transport] class for use with XMPP. It also provides
  /// a plugin mechanism to easily extend and add support for new XMPP features.
  ///
  /// The client and the component classes should extend from this class.
  WhixpBase({
    /// XMPP server host address. If null, it defaults to the host part of the
    /// provided Jabber ID
    String? host,

    /// Port number for the XMPP server, defaults to 5222
    int port = 5222,

    /// Jabber ID associated with the XMPP client
    String jabberID = '',

    /// Default XML namespace, defualts to "client"
    String? defaultNamespace,

    /// If set to `true`, attempt to use IPv6
    bool useIPv6 = false,

    /// Use Transport Layer Security (TLS) for secure communication, defaults to
    /// false. When this flag is true, then the client will try to Direct TLS
    bool useTLS = false,

    /// Defines whether the client will later call StartTLS or not
    ///
    /// When connecting to the server, there can be StartTLS handshaking and
    /// when the client and server try to handshake, we need to upgrade our
    /// connection. This flag disables that handshaking and forbids establishing
    /// a TLS connection on the client side. Defaults to `false`
    bool disableStartTLS = false,

    /// [List] of paths to a file containing certificates for verifying the
    /// server TLS certificate. Uses [Tuple2], the first side is for path to the
    /// cert file and the second to the password file
    List<Tuple2<String, String?>>? certs,

    /// Represents the duration in milliseconds for which the system will wait
    /// for a connection to be established before raising a [TimeoutException].
    ///
    /// Defaults to 2000 milliseconds
    int connectionTimeout = 2000,

    /// The maximum number of reconnection attempts that the [Transport] will
    /// make in case the connection with the server is lost or cannot be
    /// established initially. Defaults to 3
    int maxReconnectionAttempt = 3,

    /// The maximum number of consecutive `see-other-host` redirections that
    /// will be followed before quitting
    int maxRedirects = 5,

    /// [Log] instance to print out various log messages properly
    Log? logger,
  }) {
    streamNamespace = WhixpUtils.getNamespace('JABBER_STREAM');

    /// If no default namespace is provided, then client "jabber:client" will
    /// be used.
    this.defaultNamespace =
        defaultNamespace ?? WhixpUtils.getNamespace('CLIENT');

    /// requested [JabberID] from the passed jabber ID.
    requestedJID = JabberID(jabberID);

    /// [JabberID] from the passed jabber ID.
    final boundJID = JabberID(jabberID);

    /// Initialize [PluginManager].
    _pluginManager = PluginManager();

    /// Equals passed maxRedirect count to the local variable.
    _maxRedirects = maxRedirects;

    this.logger = logger ?? Log();

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

    /// Set up the [Transport] with XMPP's root stanzas.
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

    /// Initialize [RosterManager].
    _roster = roster.RosterManager(this);

    /// Add current user jid to the roster.
    _roster.add(boundJID.toString());

    /// Get current user's roster from the roster manager.
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
  @internal
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

  /// [Log] instance to print out various log messages properly.
  late final Log logger;

  /// The sasl data keeper. Works with [SASL] class and keeps various data(s)
  /// that can be used accross package.
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

  /// Register a stream feature handler.
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

  /// Create, initialize, and send a new [Presence].
  void sendPresence({
    /// The presence's show value
    String? presenceFrom,

    /// The recipient of a directed presence
    String? prsenceTo,
  }) {
    final presence = makePresence(presenceFrom: presenceFrom);
    return presence.send();
  }

  /// Create and initialize a new [Presence] stanza.
  Presence makePresence({
    /// The presence's show value
    String? presenceShow,

    /// The presence's status message
    String? presenceStatus,

    /// The connection's priority
    String? presencePriority,

    /// The recipient of a directed presence
    String? presenceTo,

    /// The sender of the presence
    String? presenceFrom,

    /// The type of presence, such as 'subscribe'
    String? presenceType,

    /// Optional nickname of the presence's sender
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

  /// Create a presence stanza associated with this stream.
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

  /// Request the roster from the server.
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

  /// Register and configure a [plugin] instance for use in this stream.
  ///
  /// [name] is the name of plugin class. Plugin names must be unique.
  void registerPlugin(String name, PluginBase plugin) {
    if (!_pluginManager.registered(name)) {
      _pluginManager.register(name, plugin);
    }
    _pluginManager.enable(name);
  }

  /// Process incoming message stanzas.
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

  /// Attempt to automatically handle subscription requests.
  ///
  /// Subscriptions will be approved if the request is from a whitelisted JID,
  /// of `autoAuthorize` is true.
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
        logger.warning('No other host specified');
        return;
      }

      transport.handleStreamError(otherHost, maxRedirects: _maxRedirects);
    }
  }

  /// Add a custom event handler that will be executed whenever its event is
  /// manually triggered.
  void addEventHandler<B>(
    String event,
    FutureOr<void> Function(B? data) listener, {
    bool once = false,
  }) =>
      transport.addEventHandler(event, listener, once: once);

  /// Password from credentials.
  String get password => credentials['password']!;
}

extension StringExtension on String {
  String capitalize() =>
      '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
}
