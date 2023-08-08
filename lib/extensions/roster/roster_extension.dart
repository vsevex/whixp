import 'dart:async';

import 'package:echo/echo.dart';
import 'package:echo/extensions/event/event.dart';
import 'package:echo/src/constants.dart';

/// An enumeration representing different show types for a presence resource.
enum ResourceShow {
  /// Indicates that the user is available for chat.
  chat,

  /// Indicates that the user is away and might not respond immediately.
  away,

  /// Indicates that the user is in "Do Not Disturb" mode and prefers not to be
  /// disturbed.
  dnd,

  /// Indicates that the user is extended away and might not return soon.
  xa
}

/// The [RosterExtension] class extends the [Extension] class to implement a
/// custom extension for roster management in an XMPP client. Implements
/// XEP-0237 protocol.
class RosterExtension extends Extension {
  /// Creates a new instance of [RosterExtension].
  ///
  /// This extension is identified with the name `roster-extension`.
  RosterExtension() : super('roster-extension');

  final _users = <RosterUser>[];
  final _usersEventius = Eventius<List<RosterUser>>(name: 'roster');
  final _callbacks =
      <void Function(List<RosterUser>, RosterUser?, RosterUser?)>[];
  final _requestCallbacks = <void Function(String)>[];
  String _ver = '';

  /// This method is not implemented and will not be affected in the use of this
  /// extension.
  @override
  void changeStatus(EchoStatus status, String? condition) {
    // throw ExtensionException.notImplementedFeature(
    //   'Roster',
    //   'Changing Connection Status',
    // );
  }

  @override
  void initialize(Echo echo) {
    /// Add required namespaces to the [Echo] class.
    echo
      ..addNamespace('ROSTER_VER', 'urn:xmpp:features:rosterver')
      ..addNamespace('NICK', 'http://jabber.org/protocol/nick')
      ..addHandler(_onReceivePresence, name: 'presence')
      ..addHandler(
        _onReceiveIQ,
        namespace: ns['ROSTER'],
        name: 'iq',
        type: 'set',
      );

    /// Attach an initial method that is responsible for firing users when there
    /// is a user added or removed or changed in the list.
    _callbacks.add((users, _, __) => _usersEventius.fire(users));

    super.echo = echo;
  }

  /// Retrieves the roster information using an IQ request as specified in the
  /// XMPP protocol. The retrieved roster contains a list of users with their
  /// presence information.
  ///
  /// * @param errorCallback A callback function that can be used to handle any
  /// error during the roster retrieval process. It takes an [EchoException]
  /// paramter, which represents the error that occured.
  ///
  /// ### Usage
  /// ```dart
  /// final roster = RosterExtension();
  ///
  /// echo.attachExtension(roster);
  /// await roster.get(errorCallback: (exception) {
  ///   log(exception);
  /// });
  /// ```
  Future<void> get({
    FutureOr<void> Function(EchoException)? errorCallback,
  }) async {
    final attributes = <String, String>{'xmlns': ns['ROSTER']!};

    /// Clear users list if versioning is supported.
    if (_supportVersioning) {
      attributes['ver'] = _ver;
      _users.clear();
      _usersEventius.clear();
    }

    final iq = EchoBuilder.iq(
      attributes: {'type': 'get', 'id': echo!.getUniqueId('roster')},
    ).c('query', attributes: attributes);

    return echo!.sendIQ(
      element: iq.nodeTree!,
      waitForResult: true,
      resultCallback: (iq) => _updateUsers(iq),
      errorCallback: errorCallback?.call,
    );
  }

  /// Adds a new contact to the user's roster using an IQ request as specified
  /// in the protocol. The contact's Jabber ID (JID), optional display name, and
  /// group memberships can be specified.
  ///
  /// * @param jid The Jabber ID (JID) of the contact to be added to the roster.
  /// * @param name An optional display name for the contact. If not provided,
  /// an empty string is used.
  /// * @param groups A list of group names to which the contact should be
  /// added. If not provided, the contact is not associated with any groups.
  /// * @param resultCallback A callback function that can be used to handle the
  /// result of the roster addition process.
  ///
  /// ### Usage
  /// ```dart
  /// final roster = RosterExtension();
  ///
  /// echo.attachExtension(roster);
  /// await roster.add('alyosha@localhost', name: 'vsevex', groups: ['Buddies']);
  /// ```
  Future<void> add(
    String jid, {
    String? name,
    List<String>? groups,
    FutureOr<void> Function(XmlElement)? resultCallback,
  }) async {
    final iq = EchoBuilder.iq(attributes: {'type': 'set'})
        .c('query', attributes: {'xmlns': ns['ROSTER']!}).c(
      'item',
      attributes: {'jid': jid, 'name': name ?? ''},
    );

    /// If any groups are specified, the `group` elements are added to the IQ
    /// request for each group membership.
    if (groups != null && groups.isNotEmpty) {
      for (int i = 0; i < groups.length; i++) {
        iq.c('group').t(groups[i]).up();
      }
    }

    return echo!.sendIQ(
      element: iq.nodeTree!,
      resultCallback: resultCallback,
      waitForResult: true,
    );
  }

  /// Subscribes to the presence updates of a contact using a presence stanza
  /// with a `subscribe` type.
  ///
  /// * @param jid The Jabber ID (JID) of the contact to whom a subscription
  /// request is sent.
  /// * @param message An optional message to include in the subscription
  /// request. This message can provide context or additional information
  /// for the subscription request.
  /// * @param nick An optional nickname to be associated with the subscription
  /// request. The nickname can be used as a display name for the subscriber.
  ///
  /// ### Usage
  /// ```dart
  /// final roster = RosterExtension();
  ///
  /// echo.attachExtension(roster);
  /// roster.subscribe('alyosha@localhost', message: 'Hello, blya!');
  /// ```
  void subscribe(String jid, {String? message, String? nick}) {
    final presence =
        EchoBuilder.pres(attributes: {'to': jid, 'type': 'subscribe'});
    if (message != null && message.isNotEmpty) {
      presence.c('status').t(message).up();
    }
    if (nick != null && nick.isNotEmpty) {
      presence.c('nick', attributes: {'xmlns': ns['NICK']!}).t(nick).up();
    }
    echo!.send(presence);
  }

  /// Unsubscribes from receiving presence updates of a contact using a presence
  /// stanza with an `unsubscribe` type.
  ///
  /// * @param jid The Jabber ID (JID) of the contact from whom the subscription
  /// is unsubscribed.
  /// * @param message An optional message to include in the unsubscription
  /// request. This message can provide context or additional information
  /// for the unsubscription request.
  ///
  /// ### Usage
  /// ```dart
  /// final roster = RosterExtension();
  ///
  /// echo.attachExtension(roster);
  /// roster.unsubscribe('alyosha@localhost', message: 'Bye, blya!');
  /// ```
  void unsubscribe(String jid, {String? message}) {
    final presence =
        EchoBuilder.pres(attributes: {'to': jid, 'type': 'unsubscribe'});
    if (message != null && message.isNotEmpty) {
      presence.c('status').t(message);
    }
    echo!.send(presence);
  }

  /// Authorizes a contact's subscription request using a presence stanza with
  /// a `subscribed` type.
  ///
  /// * @param jid The Jabber ID (JID) of the contact whose subscription request
  /// is being authorized.
  /// * @param message An optional message to include in the authorization. This
  /// message can provide context or additional information for the
  /// authorization.
  ///
  /// ### Usage
  /// ```dart
  /// final roster = RosterExtension();
  ///
  /// echo.attachExtension(roster);
  /// roster.authorize('alyosha@localhost', message: 'Accepted, blya!');
  /// ```
  void authorize(String jid, {String? message}) {
    final presence =
        EchoBuilder.pres(attributes: {'to': jid, 'type': 'subscribed'});
    if (message != null && message.isNotEmpty) {
      presence.c('status').t(message);
    }
    echo!.send(presence);
  }

  /// Unauthorizes a contact's subscription request using a presence stanza with
  /// an `unsubscribed` type.
  ///
  /// * @param jid The Jabber ID (JID) of the contact whose subscription request
  /// is being unauthorized.
  /// * @param message An optional message to include in the unauthorization.
  /// This message can provide context or additional information for the
  /// unauthorization.
  ///
  /// ### Usage
  /// ```dart
  /// final roster = RosterExtension();
  ///
  /// echo.attachExtension(roster);
  /// roster.unauthorize('alyosha@localhost', message: 'Rejected, blya!');
  /// ```
  void unauthorize(String jid, {String? message}) {
    final presence =
        EchoBuilder.pres(attributes: {'to': jid, 'type': 'unsubscribed'});
    if (message != null && message.isNotEmpty) {
      presence.c('status').t(message);
    }
    echo!.send(presence);
  }

  /// Updates the information of an existing contact in the user's roster using
  /// an IQ request as specified in the protocol. The contact's Jabber ID (JID),
  /// optional display name, and group memberships can be modified.
  ///
  /// * @param jid The Jabber ID (JID) of the contact whose information is
  /// being updated.
  /// * @param name An optional new display name for the contact. If not
  /// provided, the contact's current display name will be retained.
  /// * @param groups A list of new group names to which the contact should be
  /// associated. If not provided, the contact's group memberships will remain
  /// unchanged.
  /// * @param resultCallback: A callback function that can be used to handle
  /// the result of the roster update process. It takes an [XmlElement]
  /// parameter, which represents the result element of the IQ response.
  ///
  /// ### Usage
  /// ```dart
  /// final roster = RosterExtension();
  ///
  /// echo.attachExtension(roster);
  /// await roster.update(
  ///   'vsevex@localhost',
  ///   name: 'vsevex',
  ///   groups: ['Stalkers'],
  ///   resultCallback: (result) {
  ///     log(result);
  ///   }
  /// );
  /// ```
  Future<void> update(
    String jid, {
    String? name,
    List<String>? groups,
    FutureOr<void> Function(XmlElement)? resultCallback,
  }) async {
    final user = findUser(jid);
    final iq = EchoBuilder.iq(attributes: {'type': 'set'})
        .c('query', attributes: {'xmlns': ns['ROSTER']!}).c(
      'item',
      attributes: {'jid': jid, 'name': name ?? user!.name!},
    );

    if (groups != null && groups.isNotEmpty) {
      for (int i = 0; i < groups.length; i++) {
        iq.c('group').t(groups[i]).up();
      }
    }

    return echo!.sendIQ(
      element: iq.nodeTree!,
      resultCallback: resultCallback,
      waitForResult: true,
    );
  }

  /// Removes an existing contact from the user's roster using an IQ request as
  /// specified in the protocol. The contact's Jabber ID (JID) is provided to
  /// identify the contact to be removed.
  ///
  /// * @param jid The Jabber ID (JID) of the contact to be removed from the
  /// roster.
  ///
  /// ### Usage
  /// ```dart
  /// final roster = RosterExtension();
  ///
  /// echo.attachExtension(roster);
  /// await roster.remove('vsevex@localhost');
  /// ```
  ///
  Future<void> remove(String jid) async {
    final user = findUser(jid);
    if (user != null) {
      final iq = EchoBuilder.iq(attributes: {'type': 'set'})
          .c('query', attributes: {'xmlns': ns['ROSTER']!}).c(
        'item',
        attributes: {'jid': user.jid!, 'subscription': 'remove'},
      );

      return echo!.sendIQ(element: iq.nodeTree!);
    }
  }

  /// Helper method to add listener that helps to get notified when there is a
  /// change in the `users` list.
  ///
  /// If there is a need to filter the result of the users, `filter` parameter
  /// can be used.
  void users(
    void Function(List<RosterUser>) listener, {
    bool Function(List<RosterUser>)? filter,
  }) =>
      filter != null
          ? _usersEventius.addFilteredListener(listener, filter)
          : _usersEventius.addListener(listener);

  /// Registers a callback function to be called when user information is
  /// updated or modified.
  ///
  /// * @param callback The callback function that takes two [RosterUser]
  /// parameters: `user` representing the updated user information and
  /// `previousUser` representing the previous user information.
  void registerCallback(
    void Function(RosterUser?, RosterUser?) callback,
  ) =>
      _callbacks
          .add((_, user, previousUser) => callback.call(user, previousUser));

  /// Registers a callback function to be called when a subscription request is
  /// received.
  ///
  /// * @param callback The callback function that takes a [String] parameter
  /// representing the JID of the contact from whom the subscription request is
  /// received.
  void registerRequestCallback(void Function(String) callback) =>
      _requestCallbacks.add(callback);

  /// Handles the reception of a presence stanza and updates the roster's user
  /// information accordingly. This method is invoked when presence information
  /// is received from contacts.
  ///
  /// The presence information includes details about the contact's status,
  /// show type, and more.
  ///
  /// * @param presence The received presence [XmlElement].
  bool _onReceivePresence(XmlElement presence) {
    final jid = presence.getAttribute('from');
    final from = Echotils().getBareJIDFromJID(jid!);
    final user = findUser(from!);
    final type = presence.getAttribute('type');

    if (user == null) {
      if (type == 'subscribe') {
        _callRequestCallback(from);
      }
      return true;
    }
    if (type == 'unavailable') {
      user.resources.remove(Echotils().getResourceFromJID(jid));
    } else if (type == null) {
      user.resources[Echotils().getResourceFromJID(jid)!] = Resource(
        show: presence.getElement('show') != null
            ? (() {
                switch (Echotils.getText(presence.getElement('show')!)) {
                  case 'chat':
                    return ResourceShow.chat;
                  case 'away':
                    return ResourceShow.away;
                  case 'dnd':
                    return ResourceShow.dnd;
                  case 'xa':
                    return ResourceShow.xa;
                }
              }())
            : null,
        status: presence.getElement('status') != null
            ? Echotils.getText(presence.getElement('status')!)
            : null,
        priority: presence.getElement('priority') != null
            ? int.parse(Echotils.getText(presence.getElement('priority')!))
            : null,
      );
    } else {
      return true;
    }
    _callCallback(_users, user);
    return true;
  }

  /// Handles the reception of an IQ stanza and processes it to update the
  /// roster's user information.
  ///
  ///
  /// This method is invoked when IQ stanzas related to roster operations are
  /// received, such as roster retrieval and updates.
  ///
  /// * @param iq The received IQ [XmlElement].
  bool _onReceiveIQ(XmlElement iq) {
    final id = iq.getAttribute('id');
    final from = iq.getAttribute('from');

    if (from != null &&
        from.isNotEmpty &&
        from != echo!.jid &&
        from != Echotils().getBareJIDFromJID(echo!.jid)) {
      return true;
    }
    final iqResult = EchoBuilder.iq(
      attributes: {'type': 'result', 'id': id, 'from': echo!.jid},
    );
    echo!.send(iqResult);
    _updateUsers(iq);
    return true;
  }

  /// Removes a user from the roster based on the provided Jabber ID (JID).
  ///
  /// * @param jid The Jabber ID (JID) of the user to be removed.
  bool _removeUser(String jid) {
    for (int i = 0; i < _users.length; i++) {
      if (_users[i].jid == jid) {
        _users.removeAt(i);
        return true;
      }
    }
    return false;
  }

  /// Calls registered callbacks with the updated user information. This method
  /// is used to notify subscribers when user information is updated or
  /// modified.
  ///
  /// * @param users The list of roster users.
  /// * @param user The user whose information was updated.
  /// * @param previousUser The previous state of the user before the update.
  void _callCallback(
    List<RosterUser> users, [
    RosterUser? user,
    RosterUser? previousUser,
  ]) {
    for (int i = 0; i < _callbacks.length; i++) {
      _callbacks[i].call(users, user, previousUser);
    }
  }

  /// Calls registered request callbacks when a subscription request is
  /// received. This method notifies subscribers about incoming subscription
  /// requests.
  ///
  /// * @param from The JID of the contact from whom the subscription request is
  /// received.
  void _callRequestCallback(String from) {
    for (int i = 0; i < _requestCallbacks.length; i++) {
      _requestCallbacks[i].call(from);
    }
  }

  /// Updates or adds a user's information based on the provided [XmlElement]
  /// containing roster item details.
  ///
  /// * @param stanza The [XmlElement] containing roster item details.
  void _updateUser(XmlElement stanza) {
    final jid = stanza.getAttribute('jid');
    final name = stanza.getAttribute('name');
    final subscription = stanza.getAttribute('subscription');
    final ask = stanza.getAttribute('ask');
    final groups = <String>[];

    Echotils.forEachChild(
      stanza,
      'group',
      (child) => groups.add(Echotils.getText(child)),
    );

    RosterUser? user;
    RosterUser? previousUser;

    if (subscription == 'remove') {
      final hasBeenRemoved = _removeUser(jid!);
      if (hasBeenRemoved) {
        _callCallback(_users, RosterUser(jid: jid, subscription: 'remove'));
      }
      return;
    }

    user = findUser(jid!);
    if (user == null) {
      user = RosterUser(
        jid: jid,
        name: name,
        subscription: subscription,
        ask: ask,
        groups: groups,
      );
      _users.add(user);
    } else {
      previousUser = RosterUser(
        name: user.name,
        subscription: user.subscription,
        ask: user.ask,
        groups: user.groups,
      );
      user.copyWith(
        name: name,
        subscription: user.subscription,
        ask: user.ask,
        groups: user.groups,
      );
    }

    _callCallback(_users, user, previousUser);
  }

  /// Updates the roster's user information based on the received IQ stanza.
  ///
  /// * @param iq The received IQ [XmlElement].
  void _updateUsers(XmlElement iq) {
    final query = iq.getElement('query');
    if (query != null) {
      _ver = query.getAttribute('ver')!;
      Echotils.forEachChild(query, 'item', _updateUser);
    }
  }

  /// Finds a user in the roster based on the provided Jabber ID (JID).
  ///
  /// * @param jid The Jabber ID (JID) of the user to search for.
  RosterUser? findUser(String jid) {
    if (_users.isNotEmpty) {
      for (int i = 0; i < _users.length; i++) {
        if (_users[i].jid == jid) {
          return _users[i];
        }
      }
    }
    return null;
  }

  /// Determines whether the roster extension supports versioning based on the
  /// features advertised by the server. Versioning allows for efficient roster
  /// retrieval by checking whether the roster has been modified since the last
  /// retrieval.
  bool get _supportVersioning =>
      echo!.features != null && echo!.features!.getElement('ver') != null;
}

/// Represents a user in the roster along with their associated information,
/// such as Jabber ID (JID), display name, subscription status, presence ask
/// state, groups, and associated resources.
///
/// The [RosterUser] class provides methods for copying instances with modified
/// properties and comparing instances for equality.
class RosterUser {
  /// Creates a new [RosterUser] instance with the provided information.
  RosterUser({
    this.jid,
    this.name,
    this.subscription,
    this.ask,
    this.groups,
  });

  /// The Jabber ID (JID) of the user.
  final String? jid;

  /// The display name of the user.
  final String? name;

  /// The subscription status of the user.
  final String? subscription;

  /// The presence ask state of the user.
  final String? ask;

  /// The groups to which the user belongs.
  final List<String>? groups;

  /// A map containing the user's associated resources.
  final resources = <String, Resource>{};

  RosterUser copyWith({
    String? jid,
    String? name,
    String? subscription,
    String? ask,
    List<String>? groups,
  }) =>
      RosterUser(
        jid: jid ?? this.jid,
        name: name ?? this.name,
        subscription: subscription ?? this.subscription,
        ask: ask ?? this.ask,
        groups: groups ?? this.groups,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RosterUser &&
          runtimeType == other.runtimeType &&
          jid == other.jid &&
          name == other.name &&
          subscription == other.subscription &&
          ask == other.ask &&
          groups == other.groups &&
          resources == other.resources;

  @override
  int get hashCode =>
      jid.hashCode ^
      name.hashCode ^
      subscription.hashCode ^
      ask.hashCode ^
      groups.hashCode ^
      resources.hashCode;

  @override
  String toString() =>
      '''Roster User: (JID: $jid, Name: $name, Subscription: $subscription, Ask: $ask, Groups: $groups, Resources: $resources)''';
}

/// Represents a presence resource associated with a user in the roster. A
/// presence resource provides information about the user's availability,
/// status, and show type.
class Resource {
  /// Creates a new [Resource] instance with the provided properties.
  const Resource({this.priority, this.status, this.show});

  /// The priority level of the presence resource.
  final int? priority;

  /// The status message associated with the presence resource.
  final String? status;

  /// The show type indicating the user's availability.
  final ResourceShow? show;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Resource &&
          runtimeType == other.runtimeType &&
          priority == other.priority &&
          status == other.status &&
          show == other.show;

  @override
  int get hashCode => priority.hashCode ^ status.hashCode ^ show.hashCode;

  @override
  String toString() =>
      '''Resource: (Priority: $priority, Status: $status, Show: $show)''';
}
