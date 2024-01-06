part of 'manager.dart';

/// It is a single entry in a roster node, and tracks the subscription state
/// and user annotations of a single [JabberID].
class RosterItem {
  /// [RosterItem]s provide methods for handling incoming [Presence] stanzas
  /// that ensure that response stanzas are sent.
  RosterItem(
    /// The [Whixp] instance which is assigned to this roster management
    this.whixp, {
    /// The JID of  the roster item
    required this.jid,
    this.roster,

    /// The Roster's owner [JabberID]
    JabberID? owner,

    /// State fields:
    ///
    /// "from" indicates if a subscription of type "from" has been authorized
    /// "to" indicates if a subcsription of type "to" has been authorized
    /// "pending_in" indicates if a subscription request has been received from
    /// this JID and it has not been authorized yet
    /// "subscription" returns one of: "to", "from", "both", or "none" based on
    /// the stanzas of from, to, pending_in, and pending_out. Assignment to this
    /// value does not affect the states of other values
    /// "whitelisted" indicates if a subscription request from this JID should
    /// be automatically accepted
    /// "name" is an alias for the JID
    /// "groups" is a list of group for the JID
    Map<String, dynamic>? state,
  }) {
    _owner = owner ?? whixp.transport.boundJID;
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

    _transport = whixp.transport;
  }

  /// The [Whixp] instance which is assigned to this roster management.
  final WhixpBase whixp;

  /// The JID of  the roster item.
  final String jid;
  final RosterNode? roster;
  late final Map<String, dynamic> _state;

  /// A [Map] of online resources for this JID. Will contain the fields "show",
  /// "status", and "priority".
  final resources = <String, dynamic>{};

  /// Will be assigned from the [Whixp] instance later.
  late final Transport _transport;

  /// The Roster's owner [JabberID].
  late final JabberID _owner;

  /// The last [Presence] sent to this JID.
  Presence? lastStatus;

  /// Send a subscription request to the JID.
  void subscribe() {
    final presence = Presence();
    presence['to'] = jid;
    presence['type'] = 'subscribe';
    if (_transport.isComponent) {
      presence['from'] = _owner.toString();
    }
    this['pending_out'] = true;
    presence.send();
  }

  /// Authorize a received subscription request from the JID.
  void authorize() {
    this['from'] = true;
    this['pending_out'] = false;
    _subscribed();
    sendLastPresence();
  }

  /// Deny a received subscription request from the JID.
  void unauthorize() {
    this['from'] = false;
    this['pending_in'] = false;
    _unsubscribed();

    final presence = Presence();
    presence['to'] = jid;
    presence['type'] = 'unavailable';
    if (_transport.isComponent) {
      presence['from'] = _owner.toString();
    }
    presence.send();
  }

  /// Handle ack a subscription.
  void _subscribed() {
    final presence = Presence();
    presence['to'] = jid;
    presence['type'] = 'subscribed';
    if (_transport.isComponent) {
      presence['from'] = _owner.toString();
    }
    presence.send();
  }

  /// Unsubscribe from the JID.
  void unsubscribe() {
    final presence = Presence();
    presence['to'] = jid;
    presence['type'] = 'unsubscribe';
    if (_transport.isComponent) {
      presence['from'] = _owner.toString();
    }
    presence.send();
  }

  /// Handle ack an unsubscribe request.
  void _unsubscribed() {
    final presence = Presence();
    presence['to'] = jid;
    presence['type'] = 'unsubscribed';
    if (_transport.isComponent) {
      presence['from'] = _owner.toString();
    }
    presence.send();
  }

  /// Create, initialize, and send a [Presence] stanza.
  ///
  /// If no recipient is specified, send the presence immediately. Otherwise,
  /// forward the send request to the recipient's roster entry for processing.
  void sendPresence() {
    String? presenceFrom;
    String? presenceTo;
    if (_transport.isComponent) {
      presenceFrom = _owner.toString();
    }
    presenceTo = jid;
    whixp.sendPresence(presenceFrom: presenceFrom, prsenceTo: presenceTo);
  }

  void sendLastPresence() {
    if (lastStatus == null) {
      final presence = roster!.lastStatus;
      if (presence == null) {
        sendPresence();
      } else {
        presence['to'] = jid;
        if (whixp.transport.isComponent) {
          presence['from'] = _owner.toString();
        } else {
          presence.delete('from');
        }
        presence.send();
      }
    } else {
      lastStatus!.send();
    }
  }

  void handleAvailable(Presence presence) {
    final resource = JabberID(presence['from'] as String).resource;
    final data = {
      'status': presence['status'],
      'show': presence['show'],
      'priority': presence['priority'],
    };
    final gotOnline = resources.isEmpty;
    if (resources.containsKey(resource)) {
      resources[resource] = {};
    }
    final oldStatus = (resources[resource] as Map)['status'] ?? '';
    final oldShow = (resources[resource] as Map)['show'];
    resources[resource] = data;
    if (gotOnline) {
      whixp.transport.emit<Presence>('gotOnline', data: presence);
    }
    if (oldShow != presence['show'] || oldStatus != presence['status']) {
      whixp.transport.emit<Presence>('changedStatus', data: presence);
    }
  }

  void handleUnavailable(Presence presence) {
    final resource = JabberID(presence['from'] as String).resource;
    if (resources.isEmpty) {
      return;
    }
    if (resources.containsKey(resource)) {
      resources.remove(resource);
    }
    whixp.transport.emit<Presence>('changedStatus', data: presence);
    if (resources.isEmpty) {
      whixp.transport.emit<Presence>('gotOffline', data: presence);
    }
  }

  void handleSubscribe(Presence presence) {
    if (whixp.transport.isComponent) {
      if (this['from'] == null && !(this['pending_in'] as bool)) {
        this['pending_in'] = true;
        whixp.transport
            .emit<Presence>('rosterSubscriptionRequest', data: presence);
      } else if (this['from'] != null) {
        _subscribed();
      }
    } else {
      whixp.transport
          .emit<Presence>('rosterSubscriptionRequest', data: presence);
    }
  }

  void handleSubscribed(Presence presence) {
    if (whixp.transport.isComponent) {
      if (this['to'] == null && this['pending_out'] as bool) {
        this['pending_out'] = false;
        this['to'] = true;
        whixp.transport
            .emit<Presence>('rosterSubscriptionAuthorized', data: presence);
      } else if (this['from'] != null) {
        _subscribed();
      }
    } else {
      whixp.transport
          .emit<Presence>('rosterSubscriptionAuthorized', data: presence);
    }
  }

  void handleUnsubscribe(Presence presence) {
    if (whixp.transport.isComponent) {
      if (this['from'] == null && this['pending_in'] as bool) {
        this['pending_in'] = false;
        _unsubscribed();
      } else if (this['from'] != null) {
        this['from'] = false;
        _unsubscribed();
        whixp.transport
            .emit<Presence>('rosterSubscriptionRemove', data: presence);
      }
    } else {
      whixp.transport
          .emit<Presence>('rosterSubscriptionRemove', data: presence);
    }
  }

  void handleUnsubscribed(Presence presence) {
    if (whixp.transport.isComponent) {
      if (this['to'] == null && this['pending_out'] as bool) {
        this['pending_out'] = false;
      } else if (this['to'] != null && this['pending_out'] as bool) {
        this['to'] = false;
        whixp.transport
            .emit<Presence>('rosterSubscriptionRemoved', data: presence);
      }
    } else {
      whixp.transport
          .emit<Presence>('rosterSubscriptionRemoved', data: presence);
    }
  }

  /// Returns a state field's value.
  dynamic operator [](String key) {
    if (_state.containsKey(key)) {
      if (key == 'subscription') {
        return _subscription();
      }
      return _state[key];
    }
  }

  /// Set the value of a state field.
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

  /// Returns a proper subscription type based on current state.
  String _subscription() {
    if (this['to'] != null && this['from'] != null) {
      return 'both';
    } else if (this['from'] != null) {
      return 'from';
    } else if (this['to'] != null) {
      return 'to';
    }
    return 'none';
  }

  void handleProbe() {
    if (this['from'] as bool) {
      sendLastPresence();
    }
    if (this['pending_out'] as bool) {
      subscribe();
    }
    if (!(this['from'] as bool)) {
      _unsubscribed();
    }
  }

  /// Remove a JID's whitelisted status and unsubscribe if a subscription
  /// exists.
  void remove() {
    if (this['to'] != null) {
      final presence = Presence();
      presence['to'] = this['to'];
      presence['type'] = 'unsubscribe';
      if (_transport.isComponent) {
        presence['from'] = _owner.toString();
      }
      presence.send();
      this['to'] = false;
    }
    this['whitelisted'] = false;
  }

  /// Forgot current resource presence information as part of a roster reset
  /// request.
  void reset() => resources.clear();
}
