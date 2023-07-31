import 'package:echo/echo.dart';
import 'package:echo/src/constants.dart';

/// Represents Caps (short for Entity Capabilities) plugin.
///
/// CapsExtension is an implementation of the [Extension] class that provides
/// support for handling capabilities in the XMPP protocol using the
/// Capabilities feature.
///
/// This extension allows the client to advertise its capabilities to other
/// entities and discover the capabilities of other entities.
class CapsExtension extends Extension {
  /// Creates an instance of the [CapsExtension] with the provided extension
  /// name.
  ///
  /// For more information about this extension please refer to [CapsExtension]
  /// or `Readme`.
  CapsExtension() : super('caps-extension');

  /// A [Map] to store known capabilities of other entities identified by the
  /// `verification` attribute received in the presence stanzas.
  final _knownCapabilities = <String, List<Map<String, dynamic>>>{};

  /// A [Map] to store the `verification` attribute received in the presence
  /// from different entities, indexed by their respective JIDs.
  final _jidIndex = <String, String>{};

  /// Called when the connection status changes.
  @override
  void changeStatus(EchoStatus status, String? condition) {
    /// If the status is in `connected` state, it sends the client's presence
    /// with its capabilities.
    if (status == EchoStatus.connected) {
      sendPresence();
    }
  }

  @override
  void initialize(Echo echo) {
    /// CAPS feature namespace
    echo.addNamespace('CAPS', 'http://jabber.org/protocol/caps');

    /// Add the `CAPS` feature and client identity to the disco extension.
    echo.disco.addFeature(ns['CAPS']!);
    echo.disco.addIdentity(category: 'client', type: 'mobile', name: 'echo');

    /// Set up presence handler to process the incoming presence stanzas.
    echo.addHandler(
      (stanza) {
        final from = stanza.getAttribute('from');
        final c = stanza.findAllElements('c').first;
        final ver = c.getAttribute('ver');
        final node = c.getAttribute('node');

        if (!_knownCapabilities.containsKey(ver)) {
          /// If the capabilities are not known, request capabilities from the
          /// entity.
          return _requestCapabilities(to: from!, node: node!, ver: ver!);
        } else {
          _jidIndex[from!] = ver!;
        }
        if (!_jidIndex.containsKey(from) || _jidIndex[from] != ver) {
          _jidIndex[from] = ver;
        }
        return true;
      },
      namespace: ns['CAPS'],
      name: 'presence',
    );

    super.echo = echo;
  }

  /// Requests capabilities from the given entity (identified by `to` JID) with
  /// the provided `node` and `ver` attributes.
  ///
  /// * @param to The Jabber Identifier to indicate who the request is going to.
  /// * @param node A Unique Identifier for the capabilities being queried. It
  /// helps in distinguishing between different sets of caps provided by the
  /// same entity.
  /// * @param ver Stands for verification string and helps preventing poisoning
  /// of entity capabilities information.
  Future<bool> _requestCapabilities({
    required String to,
    required String node,
    required String ver,
  }) async {
    if (to != echo!.jid) {
      await echo!.disco
          .info(to, node: '$node#$ver', resultCallback: _handleDiscoInfoReply);
    }
    return true;
  }

  /// Handles the reply to the disco#info query and updates the known
  /// capabilities for the entity identified by 'from' JID.
  bool _handleDiscoInfoReply(XmlElement stanza) {
    final query = stanza.findAllElements('query').first;
    final node = query.getAttribute('node')!.split('#');
    final ver = node.first;
    final from = stanza.getAttribute('from');

    if (!_knownCapabilities.containsKey(ver) ||
        _knownCapabilities[ver] == null) {
      /// If the capabilities are not known, add them to the knownCapabilities
      /// [Map].
      final nodes = query.descendantElements.toList();
      _knownCapabilities[ver] = [];
      for (int i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        _knownCapabilities[ver]!
            .add({'name': node.name.local, 'attributes': node.attributes});
      }
      _jidIndex[from!] = ver;
    } else if (_jidIndex[from] == null || _jidIndex[from] != ver) {
      _jidIndex[from!] = ver;
    }

    return false;
  }

  /// Generates the attributes for the 'c' (capabilities) node in the client's
  /// presence.
  Map<String, String> get _generateCapsAttributes => {
        'xmlns': ns['CAPS']!,
        'hash': 'sha-1',
        'node': 'echo 0.0.6<',
        'ver': _generateVerificationString,
      };

  /// Creates the 'c' (capabilities) node for the client's presence.
  XmlElement? get _createCapsNode =>
      EchoBuilder('c', _generateCapsAttributes).nodeTree;

  void sendPresence() => echo!.send(EchoBuilder.pres().cnode(_createCapsNode!));

  /// Generates the verification string for the client's capabilities based on
  /// the identities and features supported by the client.
  ///
  /// For more information about this string please refer to the documentation:
  /// https://xmpp.org/extensions/xep-0115.html#ver
  String get _generateVerificationString {
    final verificationStringBuffer = StringBuffer();
    final identities = echo!.disco.identities;
    _sort(identities, 'category');
    _sort(identities, 'type');
    _sort(identities, 'language');
    final features = echo!.disco.features..sort();

    for (int i = 0; i < identities.length; i++) {
      final id = identities[i];
      verificationStringBuffer
        ..writeAll([id.category, id.type, id.language], '/')
        ..write(id.name)
        ..write('<');
    }

    for (int i = 0; i < features.length; i++) {
      verificationStringBuffer
        ..write(features[i])
        ..write('<');
    }

    return Echotils.btoa(
      Echotils.utf16to8(verificationStringBuffer.toString()),
    );
  }

  /// Sorts the list of [DiscoIdentity] objects based on the specified
  /// 'property'. The sorting is done in-place and returns the sorted list of
  /// identities.
  List<DiscoIdentity> _sort(List<DiscoIdentity> identities, String property) {
    if (property == 'category') {
      identities.sort((i1, i2) => i1.category.compareTo(i2.category));
    } else if (property == 'type') {
      identities.sort((i1, i2) => i1.type.compareTo(i2.type));
    } else if (property == 'language') {
      identities.sort((i1, i2) => i1.language!.compareTo(i2.language!));
    }
    return identities;
  }
}
