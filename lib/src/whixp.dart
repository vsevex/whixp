import 'dart:async';
import 'dart:io' as io;

import 'package:crypto/crypto.dart';
import 'package:dartz/dartz.dart';
import 'package:meta/meta.dart';

import 'package:whixp/src/exception.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/plugins/features.dart';
import 'package:whixp/src/roster/manager.dart' as rost;
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/features.dart';
import 'package:whixp/src/stanza/handshake.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/message.dart';
import 'package:whixp/src/stanza/presence.dart';
import 'package:whixp/src/stanza/roster.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/stream/matcher/matcher.dart';
import 'package:whixp/src/transport.dart';
import 'package:whixp/src/utils/utils.dart';

part 'client.dart';
part 'component.dart';

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

    /// If `true`, periodically send a whitespace character over the wire to
    /// keep the connection alive
    bool whitespaceKeepAlive = true,

    /// [List] of paths to a file containing certificates for verifying the
    /// server TLS certificate. Uses [Tuple2], the first side is for path to the
    /// cert file and the second to the password file
    Map<String, String?>? certs,

    /// To avoid processing on bad certification you can use this callback.
    ///
    /// Passes [io.X509Certificate] instance when returning boolean value which
    /// indicates to proceed on bad certificate or not.
    bool Function(io.X509Certificate)? onBadCertificateCallback,

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

    /// The default interval between keepalive signals when [whitespaceKeepAlive]
    /// is enabled. Represents in seconds. Defaults to `300`
    int whitespaceKeepAliveInterval = 300,

    /// [Log] instance to print out various log messages properly
    Log? logger,
    this.hivePathName = 'whixp',
    this.provideHivePath = false,
  }) {
    _streamNamespace = WhixpUtils.getNamespace('JABBER_STREAM');

    /// If no default namespace is provided, then client "jabber:client" will
    /// be used.
    _defaultNamespace = defaultNamespace ?? WhixpUtils.getNamespace('CLIENT');

    /// requested [JabberID] from the passed jabber ID.
    requestedJID = JabberID(jabberID);

    /// [JabberID] from the passed jabber ID.
    final boundJID = JabberID(jabberID);

    /// Initialize [PluginManager].
    _pluginManager = PluginManager();

    /// Equals passed maxRedirect count to the local variable.
    _maxRedirects = maxRedirects;

    _logger = logger ?? Log();

    /// Assignee for later.
    late String address;
    late String? dnsService;

    if (!isComponent) {
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
    } else {
      address = host ?? boundJID.host;
      dnsService = null;
    }

    /// Declare [Transport] with the passed params.
    transport = Transport(
      address,
      port: port,
      useIPv6: useIPv6,
      disableStartTLS: disableStartTLS,
      boundJID: boundJID,
      isComponent: isComponent,
      dnsService: dnsService,
      useTLS: useTLS,
      caCerts: certs,
      onBadCertificateCallback: onBadCertificateCallback,
      connectionTimeout: connectionTimeout,
      whitespaceKeepAlive: whitespaceKeepAlive,
      whitespaceKeepAliveInterval: whitespaceKeepAliveInterval,
      maxReconnectionAttempt: maxReconnectionAttempt,
    );

    /// Set up the transport with XMPP's root stanzas & handlers.
    transport
      ..startStreamHandler = ([attributes]) {
        String streamVersion = '';

        for (final attribute in attributes!) {
          if (attribute.localName == 'version') {
            streamVersion = attribute.value;
          } else if (attribute.qualifiedName == 'xml:lang') {
            transport.peerDefaultLanguage = attribute.value;
          }
        }

        if (!isComponent && streamVersion.isEmpty) {
          transport.emit('legacyProtocol');
        }
      }
      ..registerStanza(IQ(generateID: false))
      ..registerStanza(Presence())
      ..registerStanza(Message(includeNamespace: true))
      ..registerStanza(StreamError())
      ..registerHandler(
        CallbackHandler(
          'Presence',
          _handlePresence,
          matcher: XPathMatcher('{$_defaultNamespace}presence'),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'Presence',
          _handlePresence,
          matcher: XPathMatcher('{null}presence'),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'IM',
          _handleMessage,
          matcher: XPathMatcher('{$defaultNamespace}message'),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'IM',
          _handleMessage,
          matcher: XPathMatcher('{$defaultNamespace}body'),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'Stream Error',
          _handleStreamError,
          matcher: XPathMatcher('{$_streamNamespace}error'),
        ),
      );

    /// Initialize [RosterManager].
    roster = rost.RosterManager(this);

    /// Add current user jid to the roster.
    roster.add(boundJID.toString());

    /// Get current user's roster from the roster manager.
    clientRoster = roster[boundJID.toString()] as rost.RosterNode;

    transport
      ..addEventHandler<String>('disconnected', (_) => _handleDisconnected())
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
  late final String _streamNamespace;

  /// Late final initialization of default namespace.
  late final String _defaultNamespace;

  /// The JabberID (JID) requested for this connection.
  @internal
  late final JabberID requestedJID;

  /// The maximum number of consecutive `see-other-host` redirections that will
  /// be followed before quitting.
  late final int _maxRedirects;

  /// [Log] instance to print out various log messages properly.
  late final Log _logger;

  /// The sasl data keeper. Works with [SASL] class and keeps various data(s)
  /// that can be used accross package.
  @internal
  final saslData = <String, dynamic>{};

  /// The distinction between clients and components can be important, primarily
  /// for choosing how to handle the `to` and `from` JIDs of stanzas.
  final bool isComponent = false;

  /// Hive properties.
  final String hivePathName;
  final bool provideHivePath;

  @internal
  Map<String, String> credentials = <String, String>{};

  late final PluginManager _pluginManager;

  /// [rost.RosterManager] instance to make communication with roster easier.
  late final rost.RosterManager roster;
  late rost.RosterNode clientRoster;

  final features = <String>{};

  final _streamFeatureHandlers =
      <String, Tuple2<FutureOr<dynamic> Function(StanzaBase stanza), bool>>{};

  final _streamFeatureOrder = <Tuple2<int, String>>[];

  /// Register a stream feature handler.
  void registerFeature(
    String name,
    FutureOr<dynamic> Function(StanzaBase stanza) handler, {
    bool restart = false,
    int order = 5000,
  }) {
    _streamFeatureHandlers[name] = Tuple2(handler, restart);
    _streamFeatureOrder.add(Tuple2(order, name));
    _streamFeatureOrder.sort((a, b) => a.value1.compareTo(b.value1));
  }

  /// Unregisters a stream feature handler.
  void unregisterFeature(String name, {int order = 5000}) {
    if (_streamFeatureHandlers.containsKey(name)) {
      _streamFeatureHandlers.remove(name);
    }
    _streamFeatureOrder.remove(Tuple2(order, name));
    _streamFeatureOrder.sort((a, b) => a.value1.compareTo(b.value1));
  }

  /// Create, initialize, and send a new [Presence].
  void sendPresence({
    /// The recipient of a directed presence
    JabberID? presenceTo,

    /// The sender of the presence
    JabberID? presenceFrom,

    /// The presence's show value
    String? presenceShow,

    /// The presence's status message
    String? presenceStatus,

    /// The connection's priority
    String? presencePriority,

    /// The type of presence, such as 'subscribe'
    String? presenceType,

    /// Optional nickname of the presence's sender
    String? presenceNick,
  }) {
    final presence = makePresence(
      presenceTo: presenceTo,
      presenceFrom: presenceFrom,
      presenceShow: presenceShow,
      presenceStatus: presenceStatus,
      presencePriority: presencePriority,
      presenceType: presenceType,
      presenceNick: presenceNick,
    );
    return presence.send();
  }

  /// Create and initialize a new [Presence] stanza.
  Presence makePresence({
    /// The recipient of a directed presence
    JabberID? presenceTo,

    /// The sender of the presence
    JabberID? presenceFrom,

    /// The presence's show value
    String? presenceShow,

    /// The presence's status message
    String? presenceStatus,

    /// The connection's priority
    String? presencePriority,

    /// The type of presence, such as 'subscribe'
    String? presenceType,

    /// Optional nickname of the presence's sender
    String? presenceNick,
  }) {
    final presence = _presence(
      presenceType: presenceType,
      presenceTo: presenceTo,
      presenceFrom: presenceFrom,
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
    JabberID? presenceTo,
    JabberID? presenceFrom,
    String? presenceType,
    String? presenceShow,
    String? presenceStatus,
    String? presencePriority,
    String? presenceNick,
  }) {
    final presence = Presence(
      transport: transport,
      stanzaType: presenceType,
      stanzaTo: presenceTo,
      stanzaFrom: presenceFrom,
    );
    if (presenceShow != null) {
      presence['type'] = presenceShow;
    }
    if (presenceFrom != null && isComponent) {
      presence['from'] = transport.boundJID.full;
    }
    presence['priority'] = presencePriority;
    presence['status'] = presenceStatus;
    presence['nick'] = presenceNick;
    presence['lang'] = transport.defaultLanguage;
    return presence;
  }

  /// Creates an initializes a new [Message] stanza.
  ///
  /// [messageTo] is the receipent of the message.
  /// <br>[messageFrom] is the main contents of the message.
  /// <br>[messageSubject] is an optional subject for the message.
  /// Take a look at the [MessageType] enum for the message types.
  /// <br> [messageNick] is an optional nickname for the sender.
  Message makeMessage(
    JabberID messageTo, {
    String? messageBody,
    String? messageSubject,
    MessageType messageType = MessageType.chat,
    JabberID? messageFrom,
    String? messageNick,
  }) {
    final message = Message(
      stanzaTo: messageTo,
      stanzaFrom: messageFrom,
      stanzaType: messageType.toString(),
    );
    message['body'] = messageBody;
    message['subject'] = messageSubject;
    if (messageNick != null) {
      message['nick'] = messageNick;
    }
    return message;
  }

  /// Creates a stanza of type `get`.
  IQ makeIQGet({
    IQ? iq,
    String? queryXMLNS,
    JabberID? iqTo,
    JabberID? iqFrom,
  }) {
    iq ??= IQ(transport: transport);
    iq['type'] = 'get';
    iq['query'] = queryXMLNS;
    if (iqTo != null) {
      iq['to'] = iqTo;
    }
    if (iqFrom != null) {
      iq['from'] = iqFrom;
    }

    return iq;
  }

  /// Creates a stanza of type `set`.
  ///
  /// Optionally, a substanza may be given to use as the stanza's payload.
  IQ makeIQSet({IQ? iq, JabberID? iqTo, JabberID? iqFrom, dynamic sub}) {
    iq ??= IQ(transport: transport);
    iq['type'] = 'set';
    if (sub != null) {
      iq.add(sub);
    }
    if (iqTo != null) {
      iq['to'] = iqTo;
    }
    if (iqFrom != null) {
      iq['from'] = iqFrom;
    }

    return iq;
  }

  /// Request the roster from the server.
  void getRoster<T>({
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 10,
  }) {
    final iq = makeIQGet();

    if (features.contains('rosterver')) {
      (iq['roster'] as Roster)['ver'] = clientRoster.version;
    }

    iq.sendIQ(
      callback: (iq) {
        transport.emit<IQ>('rosterUpdate', data: iq);
        callback?.call(iq);
      },
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Registers and configures a [PluginBase] instance to use in this stream.
  void registerPlugin(PluginBase plugin) {
    if (!_pluginManager.registered(plugin.name)) {
      _pluginManager.register(plugin.name, plugin);

      /// Assign the instance of this class to the [plugin].
      plugin.base = this;
    }
    _pluginManager.enable(plugin.name, enabled: _pluginManager.enabledPlugins);
  }

  /// Responsible for retrieving an instance of a specified type [T] which
  /// extends [PluginBase] from the plugin registry.
  ///
  /// Optionally, it can activate the plugin if it is registered but not yet
  /// active.
  P? getPluginInstance<P>(String name, {bool enableIfRegistered = true}) =>
      _pluginManager.getPluginInstance<P>(name);

  /// Close the XML stream and wait for ack from the server.
  ///
  /// Calls the primary method from [transport].
  Future<void> disconnect() => transport.disconnect();

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

    if (((roster[presence['from'] as String]) as rost.RosterNode)
        .ignoreUpdates) {
      return;
    }

    if (!isComponent && JabberID(presence['to'] as String).bare.isNotEmpty) {
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

  void _handleDisconnected() {
    roster.reset();
    transport.sessionBind = false;
  }

  void _handleAvailable(Presence presence) {
    ((roster[presence['to'] as String]
            as rost.RosterNode)[presence['from'] as String] as rost.RosterItem)
        .handleAvailable(presence);
  }

  void _handleUnavailable(Presence presence) {
    ((roster[presence['to'] as String]
            as rost.RosterNode)[presence['from'] as String] as rost.RosterItem)
        .handleUnavailable(presence);
  }

  void _handleSubscribe(Presence presence) {
    ((roster[presence['to'] as String]
            as rost.RosterNode)[presence['from'] as String] as rost.RosterItem)
        .handleSubscribe(presence);
  }

  void _handleSubscribed(Presence presence) {
    ((roster[presence['to'] as String]
            as rost.RosterNode)[presence['from'] as String] as rost.RosterItem)
        .handleSubscribed(presence);
  }

  void _handleUnsubscribe(Presence presence) {
    ((roster[presence['to'] as String]
            as rost.RosterNode)[presence['from'] as String] as rost.RosterItem)
        .handleUnsubscribe(presence);
  }

  void _handleUnsubscribed(Presence presence) {
    ((roster[presence['to'] as String]
            as rost.RosterNode)[presence['from'] as String] as rost.RosterItem)
        .handleUnsubscribed(presence);
  }

  /// Attempt to automatically handle subscription requests.
  ///
  /// Subscriptions will be approved if the request is from a whitelisted JID,
  /// of `autoAuthorize` is true.
  void _handleNewSubscription(Presence presence) {
    final roster = this.roster[presence['to'] as String] as rost.RosterNode;
    final rosterItem = roster[presence['from'] as String] as rost.RosterItem;
    if (rosterItem['whitelisted'] as bool) {
      rosterItem.authorize();
      if (roster.autoAuthorize) {
        rosterItem.subscribe();
      }
    } else if (roster.autoAuthorize) {
      rosterItem.authorize();
      if (roster.autoSubscribe) {
        rosterItem.subscribe();
      }
    } else if (!roster.autoAuthorize) {
      rosterItem.unauthorize();
    }
  }

  void _handleStreamError(StanzaBase error) {
    transport.emit<StreamError>('streamError', data: error as StreamError);

    if (error['condition'] == 'see-other-host') {
      final otherHost = error['see-other-host'] as String?;
      if (otherHost == null || otherHost.isEmpty) {
        _logger.warning('No other host specified');
        return;
      }

      transport.handleStreamError(otherHost, maxRedirects: _maxRedirects);
    } else {
      transport.disconnect(reason: 'System shutted down', timeout: 0);
    }
  }

  /// Adds a custom [event] [handler] which will be executed whenever its event
  /// is manually triggered.
  void addEventHandler<B>(
    String event,
    FutureOr<void> Function(B? data) handler, {
    bool once = false,
  }) =>
      transport.addEventHandler<B>(event, handler, once: once);

  /// Password from credentials.
  String get password => credentials['password']!;
}

extension StringExtension on String {
  String capitalize() =>
      '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
}
