import 'package:echox/src/jid/jid.dart';
import 'package:echox/src/stanza/roster.dart' as roster;
import 'package:echox/src/stream/base.dart';
import 'package:echox/src/transport.dart';
import 'package:echox/src/whixp.dart';

part 'item.dart';
part 'node.dart';

/// ## Roster Manager
class RosterManager {
  RosterManager(
    this._whixp, {
    this.autoAuthorize = true,
    this.autoSubscribe = true,
  }) {
    _whixp.transport.addFilter<void>(
      mode: FilterMode.out,
      filter: _saveLastStatus,
    );
  }

  final WhixpBase _whixp;
  final bool autoAuthorize;
  final bool autoSubscribe;
  final _rosters = <String, RosterNode>{};

  StanzaBase _saveLastStatus(dynamic stanza) {
    if (stanza is Presence) {
      String subscribeFrom = (stanza['from'] as String).isEmpty
          ? _whixp.transport.boundJID.toString()
          : JabberID(stanza['from'] as String).full;
      final subscribeTo = stanza['to'] as String;

      if (subscribeFrom.isEmpty) {
        subscribeFrom = _whixp.transport.boundJID.toString();
      }

      if (stanza.showtypes.contains(stanza['type']) ||
          {'unavailable', 'available'}.contains(stanza['type'])) {
        if (subscribeTo.isNotEmpty) {
          ((this[subscribeFrom] as RosterNode)[JabberID(subscribeTo).full]
                  as RosterItem)
              .lastStatus = stanza;
        } else {
          (this[subscribeFrom] as RosterNode).lastStatus = stanza;
        }
      }
    }

    return stanza as StanzaBase;
  }

  dynamic operator [](String jid) {
    final bare = JabberID(jid).bare;

    if (!_rosters.containsKey(bare)) {
      add(bare);
      _rosters[bare]!.autoAuthorize = autoAuthorize;
      _rosters[bare]!.autoSubscribe = autoSubscribe;
    }

    return _rosters[bare];
  }

  Iterable<String> get keys => _rosters.keys;

  void add(String node) {
    final bare = JabberID(node).bare;

    if (!_rosters.containsKey(bare)) {
      _rosters[node] = RosterNode(_whixp, jid: bare);
    }
  }

  void reset() {
    for (final node in _rosters.entries) {
      (this[node.key] as RosterItem).reset();
    }
  }

  void sendPresence() {
    String? presenceFrom;
    if (_whixp.transport.isComponent) {
      // presenceFrom = jid;
    }
    _whixp.sendPresence(presenceFrom: presenceFrom);
  }
}
