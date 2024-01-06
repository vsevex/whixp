part of 'manager.dart';

/// A roster node is a roster for a single [JabberID].
class RosterNode {
  /// Creates an instance of [RosterNode] with the specified [Whixp] instance
  /// and [JabberID] which owns the Roster.
  RosterNode(this.whixp, {required this.jid});

  /// The main [WhixpBase] instance. Can be client or component.
  final WhixpBase whixp;

  /// The JID associated and owns the roster.
  final String jid;

  /// The last sent [Presence] status that was broadcast to all contact JIDs.
  Presence? lastStatus;

  /// The [RosterItem] items that this roster includes.
  final _jids = <String, RosterItem>{};

  /// Determines how authorizations are handled.
  bool autoAuthorize = true;

  /// Determines if bi-directional subscriptions are created after auto
  /// authorizing a subscription request.
  bool autoSubscribe = true;

  bool ignoreUpdates = false;

  /// Roster's version ID.
  String version = '';

  /// Return the roster item for a subscribed [JabberID].
  dynamic operator [](String key) {
    final bare = JabberID(key).bare;
    if (!_jids.containsKey(bare)) {
      add(key, save: true);
    }
    return _jids[bare];
  }

  /// Remove a roster item from the local. To remotely remove the item from the
  /// roster use [remove] method instead.
  void delete(String key) {
    final bare = JabberID(key).bare;
    if (_jids.containsKey(bare)) {
      _jids.remove(bare);
    }
  }

  /// Returns a list of all subscribed JIDs in [String] format.
  Iterable<String> get keys => _jids.keys;

  /// Returns whether the roster has a JID.
  bool hasJID(String jid) => _jids.containsKey(jid);

  /// Returns a [Map] of group names.
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

  /// Adds a new [JabberID] to the roster.
  void add(
    /// The JID for the roster item
    String jid, {
    /// An alias for the JID
    String name = '',

    /// A list of group names
    List? groups,

    /// Indicates if the JID has a subscription state of 'from'. Defaults to
    /// `false`
    bool from = false,

    /// Indicates if the JID has a subscription state of 'to'. Defaults to
    /// `false`
    bool to = false,

    /// Indicates if the JID has sent a subscription request to this
    /// connection's JID. Defaults to `false`
    bool pendingIn = false,

    /// Indicates if a subscription request has been send to this JID. Defaults
    /// to `false`
    bool pendingOut = false,

    /// Indicates if a subscription request from this JID should be
    /// automatically authorized. Defaults to `false`
    bool whitelisted = false,

    /// Indicates if the item should persisted immediately to an external
    /// datastore, if one is used. Defaults to `false`
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

  /// Update a [JabberID]'s subscription information.
  void subscribe(String jid) => (this[jid] as RosterItem).subscribe();

  /// Unsubscribe from the [JabberID].
  void unsubscribe(String jid) => (this[jid] as RosterItem).unsubscribe();

  /// Removes a [JabberID] from the roster (remote).
  void remove(String jid) {
    (this[jid] as RosterItem).remove();
    if (!whixp.transport.isComponent) {
      return update(jid, subscription: 'remove');
    }
  }

  /// Update a [JabberID]'s roster information.
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

  /// Returns [Presence] information for a [JabberID]'s resources.
  ///
  /// May return either all onlnie resources' status, or a single [resource]'s
  /// status.
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

  /// Reset the state of the roster to forget any current presence information.
  void reset() {
    for (final jid in _jids.entries) {
      (this[jid.key] as RosterItem).reset();
    }
  }

  /// Shortcut for sending a [Presence] stanza.
  ///
  /// Create, initialize, and send a [Presence] stanza.
  ///
  /// If no recipient is specified, send the presence immediately. Otherwise,
  /// forward the send request to the recipient's roster entry for processing.
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
}
