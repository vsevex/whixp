part of 'manager.dart';

class RosterNode {
  RosterNode(this.whixp, {required this.jid});

  final WhixpBase whixp;
  final String jid;
  Presence? lastStatus;
  final _jids = <String, RosterItem>{};
  bool autoAuthorize = true;
  bool autoSubscribe = true;
  bool ignoreUpdates = false;
  late String _version;

  dynamic operator [](String key) {
    final bare = JabberID(key).bare;
    if (!_jids.containsKey(bare)) {
      add(key, save: true);
    }
    return _jids[bare];
  }

  void delete(String key) {
    final bare = JabberID(key).bare;
    if (_jids.containsKey(bare)) {
      _jids.remove(bare);
    }
  }

  Iterable<String> get keys => _jids.keys;

  bool hasJID(String jid) => _jids.containsKey(jid);

  Map<dynamic, dynamic> groups() {
    final result = {};

    for (final jid in _jids.entries) {
      final groups = (_jids[jid.key]!)['groups'] as List;
      if (groups.isEmpty) {
        if (!result.containsKey('')) {
          result[''] = jid.key;
        }
      }
      for (final group in groups) {
        if (result.containsKey(group)) {
          result[group] = [];
        }
        result[group] = jid.key;
      }
    }

    return result;
  }

  void add(
    String jid, {
    String name = '',
    List? groups,
    bool from = false,
    bool to = false,
    bool pendingIn = false,
    bool pendingOut = false,
    bool whitelisted = false,
    bool save = false,
  }) {
    final bare = JabberID(jid).bare;

    final state = <String, dynamic>{
      'name': name,
      'groups': groups ?? [],
      'from': from,
      'to': to,
      'pending_in': pendingIn,
      'pending_out': pendingOut,
      'whitelisted': whitelisted,
      'subscription': 'none',
    };

    _jids[bare] = RosterItem(
      whixp,
      jid: jid,
      state: state,
      roster: this,
    );
  }

  void subscribe(String jid) => (this[jid] as RosterItem).subscribe();

  void unsubscribe(String jid) => (this[jid] as RosterItem).unsubscribe();

  void remove(String jid) {
    (this[jid] as RosterItem).remove();
    if (!whixp.transport.isComponent) {
      return update(jid, subscription: 'remove');
    }
  }

  void update(
    String jid, {
    String? name,
    String? subscription,
    List? groups,
  }) {
    (this[jid] as RosterItem)['item'] = name;
    (this[jid] as RosterItem)['groups'] = groups ?? [];

    if (!whixp.transport.isComponent) {
      final iq = IQ();
      iq.registerPlugin(roster.Roster());
      iq['type'] = 'set';
      (iq['roster'] as roster.Roster)['items'] = {
        jid: {
          'name': name,
          'subscription': subscription,
          'groups': groups,
        },
      };

      iq.sendIQ();
      return;
    }
  }

  dynamic presence(String jid, {String? resource}) {
    if (resource == null) {
      return (this[jid] as RosterItem).resources;
    }

    final defaultResource = <String, dynamic>{
      'status': '',
      'priority': 0,
      'show': '',
    };

    return (this[jid] as RosterItem).resources[resource] ?? defaultResource;
  }

  void reset() {
    for (final jid in _jids.entries) {
      (this[jid.key] as RosterItem).reset();
    }
  }

  void sendPresence() {
    String? presenceFrom;
    if (whixp.transport.isComponent) {
      presenceFrom = jid;
    }
    whixp.sendPresence(presenceFrom: presenceFrom);
  }

  void sendLastPresence() {
    if (lastStatus == null) {
      sendPresence();
    } else {
      final presence = lastStatus;
      if (whixp.transport.isComponent) {
        presence!['from'] = jid;
      } else {
        presence!.delete('from');
      }
      presence.send();
    }
  }

  String get version => '';

  set version(String version) => _version = version;
}
