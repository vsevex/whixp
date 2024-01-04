part of 'manager.dart';

class RosterItem {
  RosterItem(
    this.whixp, {
    required this.jid,
    this.roster,
    JabberID? owner,
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

  final WhixpBase whixp;
  final String jid;
  final RosterNode? roster;
  final resources = <String, dynamic>{};

  late final Transport _transport;
  late final Map<String, dynamic> _state;
  late final JabberID _owner;

  Presence? lastStatus;

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

  void authorize() {
    this['from'] = true;
    this['pending_out'] = false;
    _subscribed();
    sendLastPresence();
  }

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

  void _subscribed() {
    final presence = Presence();
    presence['to'] = jid;
    presence['type'] = 'subscribed';
    if (_transport.isComponent) {
      presence['from'] = _owner.toString();
    }
    presence.send();
  }

  void unsubscribe() {
    final presence = Presence();
    presence['to'] = jid;
    presence['type'] = 'unsubscribe';
    if (_transport.isComponent) {
      presence['from'] = _owner.toString();
    }
    presence.send();
  }

  void _unsubscribed() {
    final presence = Presence();
    presence['to'] = jid;
    presence['type'] = 'unsubscribed';
    if (_transport.isComponent) {
      presence['from'] = _owner.toString();
    }
    presence.send();
  }

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

  dynamic operator [](String key) {
    if (_state.containsKey(key)) {
      if (key == 'subscription') {
        return _subscription();
      }
      return _state[key];
    }
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

  void reset() => resources.clear();
}
