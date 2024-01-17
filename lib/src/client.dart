part of 'whixp.dart';

class Whixp extends WhixpBase {
  /// Client class for [Whixp].
  ///
  /// Extends [WhixpBase] class and represents an XMPP client with additional
  /// functionalities.
  ///
  /// [jabberID] associated with the client. This is a required parameter and
  /// should be a valid [JabberID]. Alongside the [jabberID] the [password] for
  /// authenticating the client. This is a required parameter and should be the
  /// password associated with the provided [jabberID].
  ///
  /// [host] is a server's host address. This parameter is optional and defaults
  /// to the value defined in the [WhixpBase].
  ///
  /// [language] is a default language to use in stanza communication. Defaults
  /// to `en`.
  ///
  /// [port] is the port number for the server. This parameter is optional and
  /// defaults to the value defined in the [WhixpBase].
  ///
  /// Timeout for establishing the connection (in milliseconds) is represented
  /// by the [connectionTimeout] parameter. Defaults to `2000`.
  ///
  /// If [whitespaceKeepAlive] is true, then socket periodically send a
  /// whitespace character over the wire to keep the connection alive.
  ///
  /// The default interval between keepalive signals when [whitespaceKeepAlive]
  /// is enabled. Represents in seconds. Defaults to `300`.
  ///
  /// [maxReconnectionAttempt] is the maximum number of reconnection attempts.
  /// This parameter is optional and defaults to `3`.
  ///
  /// If [useIPv6] is set to `true`, attempts to use IPv6 when connecting.
  ///
  /// [useTLS] is the DirectTLS activator. Defaults to `false`.
  ///
  /// [logger] is a [Log] instance to print out various log messages properly.
  ///
  /// [certs] is a [List] of paths to a file containing certificates for
  /// verifying the server TLS certificate.
  ///
  /// ### Example:
  /// ```dart
  /// final whixp = Whixp('vsevex@example.com', 'passwd');
  /// whixp.connect();
  /// ```
  Whixp(
    String jabberID,
    String password, {
    super.host,
    String language = 'en',
    super.port,
    super.connectionTimeout,
    super.whitespaceKeepAliveInterval,
    super.maxReconnectionAttempt,
    super.useIPv6,
    super.useTLS,
    super.disableStartTLS,
    super.whitespaceKeepAlive,
    super.logger,
    super.certs,
  }) : super(jabberID: jabberID) {
    _language = language;

    /// Automatically calls the `_setup()` method to configure the XMPP client.
    _setup();

    credentials.addAll({'password': password});
  }

  void _setup() {
    _reset();

    /// Set [streamHeader] of declared transport for initial send.
    transport
      ..streamHeader =
          "<stream:stream to='${transport.boundJID.host}' xmlns:stream='$streamNamespace' xmlns='$_defaultNamespace' xml:lang='$_language' version='1.0'>"
      ..streamFooter = "</stream:stream>";

    StanzaBase features = StreamFeatures();

    /// Register all necessary features.
    registerPlugin(FeatureBind(features));
    registerPlugin(FeatureSession(features));
    registerPlugin(FeatureStartTLS(features));
    registerPlugin(FeatureMechanisms(features));
    registerPlugin(FeatureRosterVersioning(features));
    registerPlugin(FeaturePreApproval(features));

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
          matcher: XPathMatcher('{$streamNamespace}features'),
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

  void _reset() => _streamFeatureHandlers.clear();

  /// Default language to use in stanza communication.
  late final String _language;

  Future<bool> _handleStreamFeatures(StanzaBase features) async {
    for (final feature in streamFeatureOrder) {
      final name = feature.value2;

      if ((features['features'] as Map<String, XMLBase>).containsKey(name) &&
          (features['features'] as Map<String, XMLBase>)[name] != null) {
        final handler = _streamFeatureHandlers[name]!.value1;
        final restart = _streamFeatureHandlers[name]!.value2;

        final result = await handler(features);

        if (result != null && restart) {
          return true;
        }
      }
    }

    return false;
  }

  void _handleSessionBind(String jid) =>
      _clientRoster = roster[jid] as rost.RosterNode;

  void _handleRoster(StanzaBase iq) {
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
        stanzaTo: iq['from'] != null ? JabberID(iq['from'] as String) : null,
        stanzaID: iq['id'] as String?,
        stanzaType: 'result',
      );
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
