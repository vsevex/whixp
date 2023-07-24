import 'package:echo/echo.dart';
import 'package:echo/src/constants.dart';

class CapsExtension extends Extension {
  CapsExtension() : super('caps-extension');

  final _verificationString = '';
  final _knownCapabilities = <String, List<Map<String, dynamic>>>{};
  final _jidIndex = <String, String>{};

  @override
  void changeStatus(EchoStatus status, String? condition) {
    if (status == EchoStatus.connected) {
      sendPresence();
    }
  }

  @override
  void initialize(Echo echo) {
    echo.addNamespace('CAPS', 'http://jabber.org/protocol/caps');

    echo.disco.addFeature(ns['CAPS']!);
    echo.disco.addIdentity(category: 'client', type: 'mobile', name: 'echo');
    echo.addHandler(
      (stanza) {
        final from = stanza.getAttribute('from');
        final c = stanza.findAllElements('c').first;
        final ver = c.getAttribute('ver');
        final node = c.getAttribute('node');

        if (!_knownCapabilities.containsKey(ver)) {
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

  bool _handleDiscoInfoReply(XmlElement stanza) {
    final query = stanza.findAllElements('query').first;
    final node = query.getAttribute('node')!.split('#');
    final ver = node.first;
    final from = stanza.getAttribute('from');

    if (!_knownCapabilities.containsKey(ver) ||
        _knownCapabilities[ver] == null) {
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

  Map<String, String> get _generateCapsAttributes => {
        'xmlns': ns['CAPS']!,
        'hash': 'sha-1',
        'node': 'echo 0.0.6<',
        'ver': _generateVerificationString,
      };

  XmlElement? get _createCapsNode =>
      EchoBuilder('c', _generateCapsAttributes).nodeTree;

  void sendPresence() => echo!.send(EchoBuilder.pres().cnode(_createCapsNode!));

  String get _generateVerificationString {
    if (_verificationString.isNotEmpty) {
      return _verificationString;
    }

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
