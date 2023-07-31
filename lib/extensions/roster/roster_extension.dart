part of '../../src/echo.dart';

class RosterExtension extends Extension {
  RosterExtension() : super('roster-extension');

  final items = <Map<String, String>?>[];
  final _callbacksRequest = <void Function(String)>[];

  @override
  void changeStatus(EchoStatus status, String? condition) {}

  @override
  void initialize(Echo echo) {
    echo
      ..addNamespace('ROSTER_VER', 'urn:xmpp:features:rosterver')
      ..addNamespace('NICK', 'http://jabber.org/protocol/nick');

    super.echo = echo;
  }

  bool _onReceivePresence(xml.XmlElement presence) {
    print('presence: $presence');
    return true;
    final jid = presence.getAttribute('from');
    final from = Echotils().getBareJIDFromJID(jid!);
    final item = findItem(from!);
    final type = presence.getAttribute('type');
    if (item == null) {
      if (type == 'subscribe') {
        _runCallbacks(from);
      }
      return true;
    }
    if (type == 'unavailable') {
      /// TODO: Implement unavailable callback.
    } else if (type == null) {
      /// TODO: Implement callback for type is null.
    } else {
      return true;
    }

    return true;
  }

  bool _onReceiveIQ(xml.XmlElement iq) {
    print('iq: $iq');
    return true;
  }

  void _runCallbacks(String from) {
    for (int i = 0; i < _callbacksRequest.length; i++) {
      _callbacksRequest[i].call(from);
    }
  }

  Map<String, String>? findItem(String jid) {
    if (items.isNotEmpty) {
      for (int i = 0; i < items.length; i++) {
        if (items[i] != null && items[i]![jid] == jid) {
          return items[i]!;
        }
      }
    }
    return null;
  }
}
