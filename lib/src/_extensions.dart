part of 'whixp.dart';

extension PrivateExtension on WhixpBase {
  /// Requested [JabberID] from the passed jabber ID.
  JabberID? get requestedJID => _requestedJID;

  /// The sasl data keeper. Works with [SASL] class and keeps various data(s)
  /// that can be used accross package.
  Map<String, dynamic> get saslData => _saslData;

  Transport get transport => _transport;

  /// [Session] getter.
  Session? get session => _session;

  /// Stream namespace.
  String get streamNamespace => _streamNamespace;

  /// Default namespace.
  String get defaultNamespace => _defaultNamespace;

  /// [Session] setter.
  set session(Session? session) => _session = session;

  List<Tuple2<int, String>> get streamFeatureOrder => _streamFeatureOrder;

  Map<String, Tuple2<FutureOr<bool> Function(Packet features), bool>>
      get streamFeatureHandlers => _streamFeatureHandlers;

  /// Registers a stream feature handler.
  void registerFeature(
    String name,
    FutureOr<bool> Function(Packet features) handler, {
    bool restart = false,
    int order = 5000,
  }) {
    /// Check beforehand if the corresponding feature is not in the list.
    if (_streamFeatureOrder
        .where((feature) => feature.secondValue == name)
        .isEmpty) {
      _registerFeature(name, handler, restart: restart, order: order);
    }
  }

  /// Map holder for the given user properties for the connection.
  Map<String, String?> get credentials => _credentials;

  /// Setter for _credentials.
  set credentials(Map<String, String?> credentials) =>
      _credentials = credentials;
}
