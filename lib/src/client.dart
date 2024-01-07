part of 'whixp.dart';

class Whixp extends WhixpBase {
  /// Client class for [Whixp].
  ///
  /// Extends [WhixpBase] class and represents an XMPP client with additional
  /// functionalities.
  ///
  /// ### Example:
  /// ```dart
  /// final whixp = Whixp('vsevex@example.com', 'passwd');
  /// whixp.connect();
  /// ```
  Whixp(
    /// Jabber ID associated with the client
    String jabberID,

    /// Password for authenticating the client.
    String password, {
    /// Server host address
    super.host,

    /// Port number for the server
    super.port,

    /// If set to `true`, attempt to use IPv6
    super.useIPv6,

    /// DirectTLS activator. Defaults to `false`
    super.useTLS = false,

    /// Disable StartTLS for secure communication. Defaults to `false`
    super.disableStartTLS,

    /// Default language to use in stanza communication
    String language = 'en',

    /// [List] of paths to a file containing certificates for verifying the
    /// server TLS certificate
    super.certs,

    /// [Log] instance to print out various log messages properly
    super.logger,

    /// Timeout for establishing the connection (in milliseconds). Defaults to
    /// `2000`
    super.connectionTimeout,

    /// Maximum number of reconnection attempts. Defaults to `3`
    super.maxReconnectionAttempt,
  }) : super(jabberID: jabberID) {
    _language = language;

    /// Automatically calls the `_setup()` method to configure the XMPP client.
    _setup();

    credentials.addAll({'password': password});
  }

  void _setup() {
    _reset();

    /// Set [streamHeader] of declared transport for initial send.
    transport.streamHeader =
        "<stream:stream to='${transport.boundJID.host}' xmlns:stream='$streamNamespace' xmlns='$defaultNamespace' xml:lang='$_language' version='1.0'>";
    transport.streamFooter = "</stream:stream>";

    StanzaBase features = StreamFeatures();

    /// Register all necessary features.
    registerPlugin('bind', FeatureBind(features));
    registerPlugin('session', FeatureSession(features));
    registerPlugin('starttls', FeatureStartTLS(features));
    registerPlugin('mechanisms', FeatureMechanisms(features));
    registerPlugin('rosterversioning', FeatureRosterVersioning(features));
    registerPlugin('preapproval', FeaturePreApproval(features));

    transport
      ..registerStanza(features)
      ..registerHandler(
        FutureCallbackHandler(
          'Stream Features',
          (stanza) async {
            features = features.copy(element: stanza.element);
            _handleStreamFeatures(features);
            return;
          },
          matcher: XPathMatcher('<features xmlns="$streamNamespace"/>'),
        ),
      )
      ..addEventHandler<String>(
        'sessionBind',
        (data) => _handleSessionBind(data!),
      )
      ..addEventHandler<StanzaBase>(
        'rosterUpdate',
        (stanza) => _handleRoster(stanza!),
      );

    transport.defaultLanguage = _language;
  }

  void _reset() => streamFeatureHandlers.clear();

  /// Default language to use in stanza communication.
  late final String _language;

  Future<bool> _handleStreamFeatures(StanzaBase features) async {
    for (final feature in streamFeatureOrder) {
      final name = feature.value2;

      if ((features['features'] as Map<String, XMLBase>).containsKey(name) &&
          (features['features'] as Map<String, XMLBase>)[name] != null) {
        final handler = streamFeatureHandlers[name]!.value1;
        final restart = streamFeatureHandlers[name]!.value2;

        final result = await handler(features);

        if (result != null && restart) {
          return true;
        }
      }
    }

    return false;
  }

  void _handleSessionBind(String jid) =>
      _clientRoster = _roster[jid] as roster.RosterNode;

  void _handleRoster(StanzaBase iq) {
    iq.registerPlugin(Roster());
    iq.enable('roster');
    final stanza = iq['roster'] as XMLBase;
    if (iq['type'] == 'set') {
      final bare = JabberID(iq['from'] as String).bare;
      if (bare.isNotEmpty && bare != transport.boundJID.bare) {
        throw StanzaException.serviceUnavailable(iq);
      }
    }

    final roster = _clientRoster;
    if (stanza['ver'] != null) {
      roster.version = stanza['ver'] as String;
    }

    final items = stanza['items'] as Map<String, Map<String, dynamic>>;

    final validSubs = {'to', 'from', 'both', 'none', 'remove'};
    for (final item in items.entries) {
      if (validSubs.contains(item.value['subscription'] as String)) {
        final value = item.value;
        (roster[item.key] as Roster)['name'] = value['name'];
        (roster[item.key] as Roster)['groups'] = value['groups'];
        (roster[item.key] as Roster)['from'] =
            {'from', 'both'}.contains(value['subscription']);
        (roster[item.key] as Roster)['to'] =
            {'to', 'both'}.contains(value['subscription']);
        (roster[item.key] as Roster)['pending_out'] =
            value['ask'] == 'subscribe';
      }
    }

    if (iq['type'] == 'set') {
      final response = IQ(
        stanzaTo: iq['from'] as String?,
        stanzaID: iq['id'] as String?,
        stanzaType: 'result',
      );
      response.registerPlugin(Roster());
      response.enable('roster');
      response.sendIQ();
    }
  }

  /// Connects to the server.
  ///
  /// When no address is given, a SRV lookup for the server will be attempted.
  /// If that fails, the server user in the JID will be used.
  void connect() => transport.connect();
}
