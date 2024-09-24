import 'dart:async';
import 'dart:io' as io;

import 'package:whixp/src/_static.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/plugins/markers/markers.dart';
import 'package:whixp/src/session.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/transport.dart';
import 'package:whixp/whixp.dart';

part '_extensions.dart';

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
    String? jabberID,

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
    bool pingKeepAlive = true,

    /// Optional [io.SecurityContext] which is going to be used in socket
    /// connections
    io.SecurityContext? context,

    /// To avoid processing on bad certification you can use this callback.
    ///
    /// Passes [io.X509Certificate] instance when returning boolean value which
    /// indicates to proceed on bad certificate or not.
    bool Function(io.X509Certificate cert)? onBadCertificateCallback,

    /// Represents the duration in milliseconds for which the system will wait
    /// for a connection to be established before raising a [TimeoutException].
    ///
    /// Defaults to 2000 milliseconds
    int connectionTimeout = 2000,

    /// The maximum number of consecutive `see-other-host` redirections that
    /// will be followed before quitting
    int maxRedirects = 5,

    /// The default interval between keepalive signals when
    /// [pingKeepAliveInterval] is enabled. Represents in seconds. Defaults to
    /// `300`
    int pingKeepAliveInterval = 300,

    /// [Log] instance to print out various log messages properly
    Log? logger,

    /// Whether to end session on disconnect method or not. Defaults to `true`.
    bool endSessionOnDisconnect = true,
    String internalDatabasePath = '/',
    ReconnectionPolicy? reconnectionPolicy,
  }) {
    _streamNamespace = WhixpUtils.getNamespace('JABBER_STREAM');

    /// If no default namespace is provided, then client "jabber:client" will
    /// be used.
    _defaultNamespace = defaultNamespace ?? WhixpUtils.getNamespace('CLIENT');

    /// Requested [JabberID] from the passed jabber ID.
    if (jabberID != null) {
      _requestedJID = JabberID(jabberID);
    } else {
      _requestedJID = null;
    }

    if (jabberID != null) {
      /// [JabberID] from the passed jabber ID.
      _boundJID = JabberID(jabberID);
    }

    /// Equals passed maxRedirect count to the local variable.
    _maxRedirects = maxRedirects;

    _logger = logger ?? Log();

    /// Assignee for later.
    late String address;
    late String? dnsService;

    if (host == null && _boundJID == null) {
      throw WhixpInternalException.setup(
        'You need to declare either host or jid to connect to the server.',
      );
    }

    if (!_isComponent) {
      /// Check if this class is not used for component initialization, and try
      /// to point [host] and [port] properly.
      if (host == null && _boundJID != null) {
        address = _boundJID!.host;

        if (useTLS) {
          dnsService = 'xmpps-client';
        } else {
          dnsService = 'xmpp-client';
        }
      } else if (host != null) {
        address = host;
        dnsService = null;
      }
    } else {
      address = host ?? _boundJID!.host;
      dnsService = null;
    }

    /// Declare [Transport] with the passed params.
    _transport = Transport(
      address,
      port: port,
      useIPv6: useIPv6,
      disableStartTLS: disableStartTLS,
      boundJID: _boundJID,
      dnsService: dnsService,
      useTLS: useTLS,
      context: context,
      onBadCertificateCallback: onBadCertificateCallback,
      connectionTimeout: connectionTimeout,
      pingKeepAlive: pingKeepAlive,
      internalDatabasePath: internalDatabasePath,
      pingKeepAliveInterval: pingKeepAliveInterval,
      endSessionOnDisconnect: endSessionOnDisconnect,
      reconnectionPolicy: reconnectionPolicy,
    );

    /// Initialize PubSub instance.
    PubSub.initialize();

    /// Set up the transport with XMPP's root stanzas & handlers.
    _transport
      ..startStreamHandler = (attributes) {
        String? streamVersion;

        for (final attribute in attributes.entries) {
          if (attribute.key == 'version') {
            streamVersion = attribute.value;
          } else if (attribute.value == 'xml:lang') {
            _transport.peerDefaultLanguage = attribute.value;
          }
        }

        if (!_isComponent && (streamVersion?.isEmpty ?? true)) {
          _transport.emit('legacyProtocol');
        }
      }
      ..registerHandler(
        Handler('Presence', _handlePresence)..packet('presence'),
      )
      ..registerHandler(Handler('IM', _handleMessage)..packet('message'))
      ..registerHandler(
        Handler('Stream Error', _handleStreamError)..packet('stream_error'),
      );
  }

  late final Transport _transport;

  /// Late final initialization of stream namespace.
  late final String _streamNamespace;

  /// Late final initialization of default namespace.
  late final String _defaultNamespace;

  /// The JabberID (JID) requested for this connection.
  late final JabberID? _requestedJID;

  /// The maximum number of consecutive `see-other-host` redirections that will
  /// be followed before quitting.
  late final int _maxRedirects;

  /// [Log] instance to print out various log messages properly.
  late final Log _logger;

  /// The sasl data keeper. Works with [SASL] class and keeps various data(s)
  /// that can be used accross package.
  final _saslData = <String, dynamic>{};

  /// The distinction between clients and components can be important, primarily
  /// for choosing how to handle the `to` and `from` JIDs of stanzas.
  final bool _isComponent = false;

  /// Must be parsed from passed [jabberID].
  JabberID? _boundJID;

  /// Session initializer.
  Session? _session;

  /// Map holder for the given user properties for the connection.
  Map<String, String?> _credentials = <String, String?>{};

  final _streamFeatureHandlers =
      <String, Tuple2<FutureOr<bool> Function(Packet features), bool>>{};

  final _streamFeatureOrder = <Tuple2<int, String>>[];

  /// Registers a stream feature handler.
  void _registerFeature(
    String name,
    FutureOr<bool> Function(Packet features) handler, {
    bool restart = false,
    int order = 5000,
  }) {
    _streamFeatureHandlers[name] = Tuple2(handler, restart);
    _streamFeatureOrder.add(Tuple2(order, name));
    _streamFeatureOrder.sort((a, b) => a.firstValue.compareTo(b.firstValue));
  }

  /// Create, initialize, and send a new [Presence].
  void sendPresence({
    /// The recipient of a directed presence
    JabberID? to,

    /// The sender of the presence
    JabberID? from,

    /// The presence's show value
    String? show,

    /// The presence's status message
    String? status,

    /// The type of presence, such as 'subscribe'
    String? type,

    /// Optional nickname of the presence's sender
    String? nick,

    /// The connection's priority
    int? priority,
  }) {
    final presence = _makePresence(
      presenceTo: to,
      presenceFrom: from,
      presenceShow: show,
      presenceStatus: status,
      presencePriority: priority,
      presenceType: type,
      presenceNick: nick,
    );
    return Transport.instance().send(presence);
  }

  /// Creates, initializes and sends a new [Message].
  void sendMessage(
    /// The recipient of a directed message
    JabberID to, {
    /// The contents of the message
    String? body,

    /// Optional subject for the message
    String? subject,

    /// The message's type, defaults to [MessageType.chat]
    MessageType type = MessageType.chat,

    /// The sender of the presence
    JabberID? from,

    /// Optional nickname of the message's sender
    String? nick,

    /// List of custom extensions for the message stanza
    List<MessageExtension>? extensions,

    /// List of payloads to be inserted
    List<Stanza>? payloads,

    /// Requests "is message displayed" information in-message
    bool requestDisplayedInformation = false,
  }) =>
      Transport.instance().send(
        _makeMessage(
          to,
          messageBody: body,
          messageSubject: subject,
          messageType: type,
          messageFrom: from,
          messageNick: nick,
          extensions: extensions,
          payloads: payloads,
          requestDisplayedInformation: requestDisplayedInformation,
        ),
      );

  /// Create and initialize a new [Presence] stanza.
  Presence _makePresence({
    /// The recipient of a directed presence
    JabberID? presenceTo,

    /// The sender of the presence
    JabberID? presenceFrom,

    /// The presence's show value
    String? presenceShow,

    /// The presence's status message
    String? presenceStatus,

    /// The type of presence, such as 'subscribe'
    String? presenceType,

    /// Optional nickname of the presence's sender
    String? presenceNick,

    /// The connection's priority
    int? presencePriority,
  }) {
    final presence = _presence(
      presenceType: presenceType,
      presenceTo: presenceTo,
      presenceFrom: presenceFrom,
      presenceShow: presenceShow,
      presenceNick: presenceNick,
      presencePriority: presencePriority,
      presenceStatus: presenceStatus,
    );
    if (presenceFrom != null && _isComponent) {
      presence.from = _session!.bindJID;
    }
    return presence;
  }

  /// Create a presence stanza associated with this stream.
  Presence _presence({
    JabberID? presenceTo,
    JabberID? presenceFrom,
    String? presenceType,
    String? presenceShow,
    String? presenceStatus,
    String? presenceNick,
    int? presencePriority,
  }) {
    final presence = Presence(
      show: presenceShow,
      priority: presencePriority,
      status: presenceStatus,
      nick: presenceNick,
    )
      ..to = presenceTo
      ..from = presenceFrom
      ..type = presenceType;
    if (presenceFrom != null && _isComponent) {
      presence.from = _session!.bindJID;
    }

    return presence;
  }

  /// Creates an initializes a new [Message] stanza.
  ///
  /// [messageTo] is the receipent of the message.
  /// <br>[messageFrom] is the main contents of the message.
  /// <br>[messageSubject] is an optional subject for the message.
  /// Take a look at the [MessageType] enum for the message types.
  /// <br> [messageNick] is an optional nickname for the sender.
  Message _makeMessage(
    JabberID messageTo, {
    String? messageBody,
    String? messageSubject,
    MessageType messageType = MessageType.chat,
    JabberID? messageFrom,
    String? messageNick,
    List<MessageExtension>? extensions,
    required bool requestDisplayedInformation,
    List<Stanza>? payloads,
  }) {
    final message =
        Message(body: messageBody, subject: messageSubject, nick: messageNick)
          ..to = messageTo
          ..from = messageFrom
          ..type = messageType.name;

    if (extensions?.isNotEmpty ?? false) {
      for (final extension in extensions!) {
        message.addExtension(extension);
      }
    }

    if (payloads?.isNotEmpty ?? false) {
      for (final payload in payloads!) {
        message.addPayload(payload);
      }
    }

    if (requestDisplayedInformation) return message.makeMarkable;

    return message;
  }

  /// Sends a message to the [messageTo] sender to inform that the message is
  /// displayed by the receiver. [messageID] must be attached.
  void sendDisplayedMessage(
    JabberID messageTo, {
    required String messageID,
    JabberID? messageFrom,
  }) {
    final message = Message()
      ..to = messageTo
      ..from = messageFrom;

    Transport.instance().send(message.makeDisplayed(messageID));
  }

  /// Sends stanza via [Transport] instance.
  void send(Stanza stanza) => Transport.instance().send(stanza);

  /// Close the XML stream and wait for ack from the server.
  ///
  /// Calls the primary method from [Transport].
  Future<void> disconnect({bool consume = true}) =>
      Transport.instance().disconnect(consume: consume);

  /// Processes incoming message stanzas.
  void _handleMessage(Packet message) {
    if (message is! Message) return;
    final to = message.to;

    if (!_isComponent && (to != null || to!.bare.isEmpty)) {
      message.to = transport.boundJID;
    }

    transport.emit<Message>('message', data: message);
  }

  void _handleStreamError(Packet error) {
    if (error is! StreamError) return;
    _transport.emit<StreamError>('streamError', data: error);

    if (error.seeOtherHost) {
      final otherHost = error.text;
      if (otherHost == null || otherHost.isEmpty) {
        _logger.warning('No other host specified');
        return;
      }

      _transport.handleStreamError(otherHost, maxRedirects: _maxRedirects);
    } else {
      _transport.disconnect(consume: false);
    }
  }

  /// Handles the presence packet by emitting appropriate events based on the
  /// packet type.
  ///
  /// [packet] is the incoming presence packet.
  void _handlePresence(Packet packet) {
    if (packet is! Presence) return;
    final type = packet.type;

    transport.emit<Presence>('presence', data: packet);
    if (type?.isNotEmpty ?? false) {
      transport.emit<Presence>('presence_$type', data: packet);
    }

    if (presenceTypes.contains(type)) {
      transport.emit<Presence>('changed_subscription', data: packet);
    }
  }

  /// Adds a custom [event] [handler] which will be executed whenever its event
  /// is manually triggered.
  void addEventHandler<B>(
    String event,
    FutureOr<void> Function(B? data) handler, {
    bool once = false,
  }) =>
      _transport.addEventHandler<B>(event, handler, once: once);

  /// Password from credentials.
  String get password => _credentials['password']!;
}

extension StringExtension on String {
  String capitalize() =>
      '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
}
