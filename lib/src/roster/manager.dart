import 'package:meta/meta.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/presence.dart';
import 'package:whixp/src/stanza/roster.dart' as roster;
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/transport.dart';
import 'package:whixp/src/whixp.dart';

part 'item.dart';
part 'node.dart';

/// ## Roster Manager
///
/// [Whixp] roster manager.
///
/// The roster is divided into "node"s, where each node is responsible for
/// single JID.
class RosterManager {
  /// Creates an instance for [RosterManager] with the provided [Whixp] instance
  /// and several optional flags.
  RosterManager(
    /// The main [Whixp] instance.
    this._whixp, {
    /// Default autoAuthorize value for the new roster nodes
    this.autoAuthorize = true,

    /// Default autoSubscribe value for the new roster nodes
    this.autoSubscribe = true,
  }) {
    _whixp.transport.addFilter<void>(
      mode: FilterMode.out,
      filter: _saveLastStatus,
    );
  }

  final WhixpBase _whixp;

  /// Default autoAuthorize value for the new roster nodes.
  final bool autoAuthorize;

  /// Default autoSubscribe value for the new roster nodes.
  final bool autoSubscribe;

  /// Keeps [RosterNode] instances for this roster.
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

  /// Returns the roster node for a JID.
  ///
  /// A new roster node will be created if one does not already exist.
  dynamic operator [](String jid) {
    final bare = JabberID(jid).bare;

    if (!_rosters.containsKey(bare)) {
      add(bare);
      _rosters[bare]!.autoAuthorize = autoAuthorize;
      _rosters[bare]!.autoSubscribe = autoSubscribe;
    }

    return _rosters[bare];
  }

  /// Returns the JIDs managed by the roster.
  Iterable<String> get keys => _rosters.keys;

  /// Adds a new roster node for the given JID.
  void add(String node) {
    final bare = JabberID(node).bare;

    if (!_rosters.containsKey(bare)) {
      _rosters[node] = RosterNode(_whixp, jid: bare);
    }
  }

  /// Resets the state of the roster to forget any current [Presence]
  /// information.
  void reset() {
    for (final node in _rosters.entries) {
      (this[node.key] as RosterItem).reset();
    }
  }

  /// Create, initialize, and send a [Presence] stanza.
  ///
  /// If no recipient is specified, send the presence immediately. Otherwise,
  /// forward the send request to the recipient's roster entry for processing.
  void sendPresence() {
    JabberID? presenceFrom;
    if (_whixp.transport.isComponent) {
      presenceFrom = _whixp.transport.boundJID;
    }
    _whixp.sendPresence(presenceFrom: presenceFrom);
  }
}
