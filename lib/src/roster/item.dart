import 'package:echox/src/jid/jid.dart';
import 'package:echox/src/stanza/presence.dart';
import 'package:echox/src/transport/transport.dart';

class RosterItem {
  RosterItem(
    this.transport, {
    required this.jid,
    JabberIDTemp? owner,
    Map<String, dynamic>? state,
  }) {
    _owner = owner ?? transport.boundJID;
    _state = state ??
        {
          'from': false,
          'to': false,
          'pending_in': false,
          'pending_out': false,
          'whitelisted': false,
          'subscription': 'none',
          'name': '',
          'groups': <String>[],
        };
  }

  final Transport transport;
  final JabberIDTemp jid;
  late final Map<String, dynamic> _state;
  late final JabberIDTemp _owner;

  void subscribe() {
    final presence = Presence(transport: transport);
    presence['to'] = jid;
    presence['type'] = 'subscribe';
    if (transport.isComponent) {
      presence['from'] = _owner;
    }
    this['pending_out'] = true;
    presence.send();
  }

  void operator []=(String attribute, dynamic value) {
    if (_state.containsKey(attribute)) {
      if ({'name', 'subscription', 'groups'}.contains(attribute)) {
        _state[attribute] = value;
      } else {
        final val = value.toString().toLowerCase();
        _state[attribute] = ['true', '1', 'on', 'yes'].contains(val);
      }
    }
  }
}
