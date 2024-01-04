part of 'whixp.dart';

class Whixp extends WhixpBase {
  Whixp(
    String jabberID,
    String password, {
    super.host,
    super.port,
    super.useIPv6,
    super.useTLS = true,
    super.disableStartTLS,
    super.certs,
    this.language = 'en',
    super.connectionTimeout,
    super.maxReconnectionAttempt,
  }) : super(jabberID: jabberID) {
    setup();

    credentials.addAll({'password': password});
  }

  void setup() {
    reset();

    /// Set [streamHeader] of declared transport for initial send.
    transport.streamHeader =
        "<stream:stream to='${transport.boundJID.host}' xmlns:stream='$streamNamespace' xmlns='$defaultNamespace' xml:lang='$language' version='1.0'>";
    transport.streamFooter = "</stream:stream>";

    StanzaBase features = StreamFeatures();

    registerPlugin('bind', FeatureBind(features, base: this));
    registerPlugin('session', FeatureSession(features, base: this));
    registerPlugin('starttls', FeatureStartTLS(features, base: this));
    registerPlugin('mechanisms', FeatureMechanisms(features, base: this));
    registerPlugin(
      'rosterversioning',
      FeatureRosterVersioning(features, base: this),
    );
    registerPlugin('preapproval', FeaturePreApproval(features, base: this));

    transport
      ..registerStanza(features)
      ..registerHandler(
        FutureCallbackHandler(
          'Stream Features',
          (stanza) async {
            features = features.copy(stanza.element);
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

    transport.defaultLanguage = language;
  }

  void reset() {
    streamFeatureHandlers.clear();
  }

  /// Default language to use in stanza communication.
  final String language;

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
    print('items is $items');

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

  void connect() => transport.connect();
}
