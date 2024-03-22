part of 'pubsub.dart';

class PubSubStanza extends XMLBase {
  PubSubStanza({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.pluginMultiAttribute,
    super.pluginIterables,
    super.element,
    super.parent,
  }) : super(
          name: 'pubsub',
          namespace: _$namespace,
          pluginAttribute: 'pubsub',
          interfaces: <String>{},
        ) {
    registerPlugin(PubSubAffiliations());
    registerPlugin(PubSubSubscription(namespace: _$namespace));
    registerPlugin(PubSubSubscriptions());
    registerPlugin(PubSubItems());
    registerPlugin(PubSubCreate());
    registerPlugin(PubSubDefault());
    registerPlugin(PubSubPublish());
    registerPlugin(PubSubRetract());
    registerPlugin(PubSubUnsubscribe());
    registerPlugin(PubSubSubscribe());
    registerPlugin(PubSubConfigure());
    registerPlugin(PubSubOptions());
    registerPlugin(PubSubPublishOptions());
    registerPlugin(RSMStanza());
  }

  @override
  PubSubStanza copy({xml.XmlElement? element, XMLBase? parent}) => PubSubStanza(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        pluginMultiAttribute: pluginMultiAttribute,
        pluginIterables: pluginIterables,
        element: element,
        parent: parent,
      );
}

/// OWNER ----------------------------------------------------------------

/// The owner of a PubSub node or service is the user or entity that has
/// administrative privileges over that particular node. This ownership grants
/// certain rights, such as configuring the node, managing subscriptions, and
/// setting access controls.
///
/// This stanza more specifically refers to the global generalization of the
/// Publish-Subscribe plugin stanza and other substanzas will be available
/// through this one.
class PubSubOwnerStanza extends XMLBase {
  PubSubOwnerStanza({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.element,
    super.parent,
  }) : super(
          name: 'pubsub',
          namespace: _$owner,
          pluginAttribute: 'pubsub_owner',
          interfaces: <String>{},
        ) {
    registerPlugin(PubSubOwnerDefaultConfig());
    registerPlugin(PubSubOwnerAffiliations());
    registerPlugin(PubSubOwnerConfigure());
    registerPlugin(PubSubOwnerDefault());
    registerPlugin(PubSubOwnerDelete());
    registerPlugin(PubSubOwnerPurge());
    registerPlugin(PubSubOwnerSubscriptions());
  }

  @override
  PubSubOwnerStanza copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubOwnerStanza(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        element: element,
        parent: parent,
      );
}

class PubSubOwnerDefaultConfig extends XMLBase {
  PubSubOwnerDefaultConfig({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.getters,
    super.setters,
    super.element,
    super.parent,
  }) : super(
          name: 'default',
          namespace: _$owner,
          pluginAttribute: 'default',
          includeNamespace: false,
          interfaces: <String>{'node', 'config'},
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('config'): (args, base) => _config,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('config'): (value, args, base) => _setConfig(value),
    });

    registerPlugin(Form());
  }

  Form get _config => this['form'] as Form;

  void _setConfig(dynamic value) {
    delete('form');
    add(value);
  }

  @override
  PubSubOwnerDefaultConfig copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubOwnerDefaultConfig(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
      );
}

class PubSubOwnerAffiliations extends PubSubAffiliations {
  PubSubOwnerAffiliations({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.element,
    super.parent,
  }) : super(namespace: _$owner) {
    registerPlugin(PubSubOwnerAffiliation(), iterable: true);
  }

  @override
  PubSubOwnerAffiliations copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubOwnerAffiliations(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        element: element,
        parent: parent,
      );
}

class PubSubOwnerAffiliation extends PubSubAffiliation {
  PubSubOwnerAffiliation({
    super.getters,
    super.setters,
    super.element,
    super.parent,
  }) : super(namespace: _$owner, interfaces: <String>{'affiliation', 'jid'});

  @override
  PubSubOwnerAffiliation copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubOwnerAffiliation(
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
      );
}

class PubSubOwnerConfigure extends PubSubConfigure {
  PubSubOwnerConfigure({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.getters,
    super.element,
    super.parent,
  }) : super(namespace: _$owner, interfaces: <String>{'node'}) {
    registerPlugin(Form());
  }

  @override
  PubSubOwnerConfigure copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubOwnerConfigure(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        getters: getters,
        element: element,
        parent: parent,
      );
}

class PubSubOwnerDefault extends PubSubOwnerConfigure {
  PubSubOwnerDefault({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.getters,
    super.element,
    super.parent,
  }) {
    registerPlugin(Form());
  }

  @override
  PubSubOwnerDefault copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubOwnerDefault(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        getters: getters,
        element: element,
        parent: parent,
      );
}

class PubSubOwnerDelete extends XMLBase {
  PubSubOwnerDelete({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.getters,
    super.setters,
    super.deleters,
    super.element,
    super.parent,
  }) : super(
          name: 'delete',
          namespace: _$owner,
          includeNamespace: false,
          pluginAttribute: 'delete',
          interfaces: <String>{'node'},
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('required'): (args, base) => _required,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('required'): (value, args, base) => _setRequired(value),
    });

    addDeleters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('required'): (args, base) => _deleteRequired(),
    });

    registerPlugin(PubSubOwnerRedirect());
  }

  bool get _required {
    final required = element!.getElement('required', namespace: namespace);
    return required != null;
  }

  void _setRequired(dynamic value) {
    if (<dynamic>{true, 'True', 'true', '1'}.contains(value)) {
      element!.children.add(WhixpUtils.xmlElement('required'));
    } else if (this['required'] as bool) {
      delete('required');
    }
  }

  void _deleteRequired() {
    final required = element!.getElement('required', namespace: namespace);
    if (required != null) {
      element!.children.remove(required);
    }
  }

  @override
  PubSubOwnerDelete copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubOwnerDelete(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}

class PubSubOwnerPurge extends XMLBase {
  PubSubOwnerPurge({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.getters,
    super.setters,
    super.deleters,
    super.element,
    super.parent,
  }) : super(
          name: 'purge',
          namespace: _$owner,
          includeNamespace: false,
          pluginAttribute: 'purge',
          interfaces: <String>{'node'},
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('required'): (args, base) => _required,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('required'): (value, args, base) => _setRequired(value),
    });

    addDeleters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('required'): (args, base) => _deleteRequired(),
    });
  }

  bool get _required {
    final required = element!.getElement('required', namespace: namespace);
    return required != null;
  }

  void _setRequired(dynamic value) {
    if (<dynamic>{true, 'True', 'true', '1'}.contains(value)) {
      element!.children.add(WhixpUtils.xmlElement('required'));
    } else if (this['required'] as bool) {
      delete('required');
    }
  }

  void _deleteRequired() {
    final required = element!.getElement('required', namespace: namespace);
    if (required != null) {
      element!.children.remove(required);
    }
  }

  @override
  PubSubOwnerPurge copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubOwnerPurge(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}

class PubSubOwnerRedirect extends XMLBase {
  PubSubOwnerRedirect({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.getters,
    super.setters,
    super.element,
    super.parent,
  }) : super(
          name: 'redirect',
          namespace: _$owner,
          pluginAttribute: 'redirect',
          interfaces: <String>{'node', 'jid'},
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('jid'): (args, base) => _jid,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('jid'): (value, args, base) => _setJid(value as JabberID),
    });
  }

  JabberID? get _jid {
    final jid = getAttribute('jid');
    if (jid.isEmpty) {
      return null;
    }
    return JabberID(jid);
  }

  void _setJid(JabberID jid) => setAttribute('jid', jid.toString());

  @override
  PubSubOwnerRedirect copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubOwnerRedirect(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
      );
}

class PubSubOwnerSubscriptions extends PubSubSubscriptions {
  PubSubOwnerSubscriptions({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.element,
    super.parent,
  }) : super(namespace: _$owner) {
    registerPlugin(PubSubOwnerSubscription(), iterable: true);
  }

  @override
  PubSubOwnerSubscriptions copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubOwnerSubscriptions(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        element: element,
        parent: parent,
      );
}

class PubSubOwnerSubscription extends XMLBase {
  PubSubOwnerSubscription({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.getters,
    super.setters,
    super.element,
    super.parent,
  }) : super(
          name: 'subscription',
          namespace: _$owner,
          pluginAttribute: 'subscription',
          interfaces: <String>{'jid', 'subscription'},
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('jid'): (args, base) => _jid,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('jid'): (value, args, base) => _setJid(value as JabberID),
    });

    registerPlugin(PubSubSubscription(), iterable: true);
  }

  JabberID? get _jid {
    final jid = getAttribute('jid');
    if (jid.isEmpty) {
      return null;
    }
    return JabberID(jid);
  }

  void _setJid(JabberID jid) => setAttribute('jid', jid.toString());

  @override
  PubSubOwnerSubscription copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubOwnerSubscription(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
      );
}

/// END OWNER ------------------------------------------------------------

/// To manage permissions, the protocol defined herein uses a hierarchy of
/// `affiliations`, similiar to those introduced in MUC.
///
/// All affiliations MUST be based on a bare JID (<vsevex@localhost> or
/// <example.com>) instead of a full JID (<vsevex@localhost/resource>).
///
/// Support for the "owner" and "none" affiliations is REQUIRED. Support for
/// all other affiliations is RECOMMENDED. For each non-required affiliation
/// supported by an implementation, it SHOULD return a service discovery feature
/// of "name-affiliation" where "name" is the name of the affiliation, such as
/// "member", "outcast", or "publisher".
///
/// see <https://xmpp.org/extensions/xep-0060.html#affiliations>
class PubSubAffiliation extends XMLBase {
  PubSubAffiliation({
    String? namespace,
    super.interfaces = const <String>{'node', 'affiliation', 'jid'},
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.getters,
    super.setters,
    super.element,
    super.parent,
  }) : super(
          name: 'affiliation',
          includeNamespace: false,
          pluginAttribute: 'affiliation',
        ) {
    this.namespace = namespace ?? _$namespace;

    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('jid'): (args, base) => _jid,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('jid'): (value, args, base) => _setJid(value as JabberID),
    });
  }

  JabberID? get _jid {
    final jid = getAttribute('jid');
    if (jid.isEmpty) {
      return null;
    }
    return JabberID(jid);
  }

  void _setJid(JabberID jid) => setAttribute('jid', jid.toString());

  @override
  PubSubAffiliation copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubAffiliation(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
      );
}

class PubSubAffiliations extends XMLBase {
  PubSubAffiliations({
    String? namespace,
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.element,
    super.parent,
  }) : super(
          name: 'affiliations',
          includeNamespace: false,
          pluginAttribute: 'affiliations',
          interfaces: <String>{'node'},
        ) {
    this.namespace = namespace ?? _$namespace;

    registerPlugin(PubSubAffiliation(), iterable: true);
  }

  @override
  PubSubAffiliations copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubAffiliations(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        element: element,
        parent: parent,
      );
}

/// Subscriptions to a node may exist in several states.
///
/// None - The node MUST NOT send event notifications or payloads to the Entity.
///
/// Pending -	An entity has requested to subscribe to a node and the request has
/// not yet been approved by a node owner. The node MUST NOT send event
/// notifications or payloads to the entity while it is in this state.
///
/// Unconfigured - An entity has subscribed but its subscription options have
/// not yet been configured. The node MAY send event notifications or payloads
/// to the entity while it is in this state. The service MAY timeout
/// unconfigured subscriptions.
///
/// Subscribed - An entity is subscribed to a node. The node MUST send all event
/// notifications (and, if configured, payloads) to the entity while it is in
/// this state (subject to subscriber configuration and content filtering).
class PubSubSubscription extends XMLBase {
  PubSubSubscription({
    super.namespace,
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.getters,
    super.setters,
    super.element,
    super.parent,
  }) : super(
          name: 'subscription',
          includeNamespace: false,
          pluginAttribute: 'subscription',
          interfaces: <String>{'node', 'subscription', 'subid', 'jid'},
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('jid'): (args, base) => _jid,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('jid'): (value, args, base) => _setJid(value as JabberID),
    });

    registerPlugin(PubSubSubscribeOptions());
  }

  JabberID get _jid => JabberID(getAttribute('jid'));

  void _setJid(JabberID jid) => setAttribute('jid', jid.toString());

  @override
  PubSubSubscription copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubSubscription(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
      );
}

class PubSubSubscriptions extends XMLBase {
  PubSubSubscriptions({
    String? namespace,
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.pluginIterables,
    super.element,
    super.parent,
  }) : super(
          name: 'subscriptions',
          includeNamespace: false,
          pluginAttribute: 'subscriptions',
          interfaces: <String>{'node'},
        ) {
    this.namespace = namespace ?? _$namespace;

    registerPlugin(PubSubSubscription(), iterable: true);
  }

  List<PubSubSubscription> get subscriptions {
    if (iterables.isNotEmpty) {
      return iterables
          .map((iterable) => PubSubSubscription(element: iterable.element))
          .toList();
    }
    return <PubSubSubscription>[];
  }

  @override
  PubSubSubscriptions copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubSubscriptions(
        namespace: namespace,
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        pluginIterables: pluginIterables,
        element: element,
        parent: parent,
      );
}

/// If a service supports subscription options it MUST advertise that fact in
/// its response to a "disco#info" query by including a feature whose `var`
/// attribute is "pubsub#subscription-options".
///
/// ### Example:
/// ```xml
/// <iq type='result'
///     from='pubsub.example.com'
///     to='vsevex@example.com/mobile'
///     id='feature1'>
///   <query xmlns='http://jabber.org/protocol/disco#info'>
///     ...
///     <feature var='http://jabber.org/protocol/pubsub#subscription-options'/>
///     ...
///   </query>
/// </iq>
/// ```
class PubSubSubscribeOptions extends XMLBase {
  PubSubSubscribeOptions({
    super.getters,
    super.setters,
    super.deleters,
    super.element,
    super.parent,
  }) : super(
          name: 'subscribe-options',
          namespace: _$namespace,
          includeNamespace: false,
          pluginAttribute: 'suboptions',
          interfaces: <String>{'required'},
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('required'): (args, base) => _required,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('required'): (value, args, base) => _setRequired(value),
    });

    addDeleters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('required'): (args, base) => _deleteRequired(),
    });
  }

  bool get _required {
    final required = element!.getElement('required', namespace: namespace);
    return required != null;
  }

  void _setRequired(dynamic value) {
    if (<dynamic>{true, 'True', 'true', '1'}.contains(value)) {
      element!.children.add(WhixpUtils.xmlElement('required'));
    } else if (this['required'] as bool) {
      delete('required');
    }
  }

  void _deleteRequired() {
    final required = element!.getElement('required', namespace: namespace);
    if (required != null) {
      element!.children.remove(required);
    }
  }

  @override
  PubSubSubscribeOptions copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubSubscribeOptions(
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}

/// When a subscription request is successfully processed, the service MAY send
/// the last published item to the new subscriber. The message containing this
/// item SHOULD be stamped with extended information qualified by the
/// 'urn:xmpp:delay' namespace.
///
/// ### Example:
/// ```xml
/// <message from='pubsub.example.com' to='vsevex@example.com'>
///   <event xmlns='http://jabber.org/protocol/pubsub#event'>
///     <items node='princely_musings'>
///       <item id='ae890ac52d0df67ed7cfdf51b644e901'>
///         <entry xmlns='http://www.w3.org/2005/Atom'>
///           <title>Soliloquy</title>
///           <summary>
/// To be, or not to be: that is the question:
/// Whether 'tis nobler in the mind to suffer
/// The slings and arrows of outrageous fortune,
/// Or to take arms against a sea of troubles,
/// And by opposing end them?
///           </summary>
///           <link rel='alternate' type='text/html'/>
///           <published>2003-12-13T18:30:02Z</published>
///           <updated>2003-12-13T18:30:02Z</updated>
///         </entry>
///       </item>
///     </items>
///   </event>
///   <delay xmlns='urn:xmpp:delay' stamp='2003-12-13T23:58:37Z'/>
/// </message>
/// ```
class PubSubItem extends XMLBase {
  PubSubItem({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.getters,
    super.setters,
    super.deleters,
    super.element,
    super.parent,
  }) : super(
          name: 'item',
          includeNamespace: false,
          pluginAttribute: 'item',
          interfaces: <String>{'id', 'payload'},
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('payload'): (args, base) => payload,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('payload'): (value, args, base) => _setPayload(value),
    });

    addDeleters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('payload'): (args, base) => _deletePayload(),
    });

    registerPlugin(AtomEntry());
  }

  xml.XmlElement? get payload {
    if (element!.childElements.isNotEmpty) {
      return element!.childElements.first;
    }
    return null;
  }

  void _setPayload(dynamic value) {
    delete('payload');
    if (value is XMLBase) {
      if (pluginTagMapping.containsKey(value.tag)) {
        initPlugin(value.pluginAttribute, existingXML: value.element);
      }
      element!.children.add(value.element!.copy());
    } else if (value is xml.XmlElement) {
      element!.children.add(value.copy());
    }
  }

  void _deletePayload() {
    for (final child in element!.childElements) {
      element!.children.remove(child);
    }
  }

  @override
  PubSubItem copy({xml.XmlElement? element, XMLBase? parent}) => PubSubItem(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}

class PubSubItems extends XMLBase {
  PubSubItems({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.setters,
    super.element,
    super.parent,
  }) : super(
          name: 'items',
          namespace: _$namespace,
          includeNamespace: false,
          pluginAttribute: 'items',
          interfaces: <String>{'node', 'max_items'},
        ) {
    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('maxItems'): (value, args, base) =>
          _setMaxItems(value as int),
    });

    registerPlugin(PubSubItem(), iterable: true);
  }

  Iterable<PubSubItem> get allItems {
    final allItems = element!.findAllElements('item', namespace: namespace);
    final iitems = <PubSubItem>[];

    for (final item in allItems) {
      iitems.add(PubSubItem(element: item));
    }

    return iitems;
  }

  void _setMaxItems(int value) {
    setAttribute('max_items', value.toString());
  }

  @override
  PubSubItems copy({xml.XmlElement? element, XMLBase? parent}) => PubSubItems(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        setters: setters,
        element: element,
        parent: parent,
      );
}

/// An entity may want to create a new node. However, a service MAY disallow
/// creation of nodes based on the identity of the requesting entity, or MAY
/// disallow node creation altogether (e.g., reserving that privilege to a
/// service-wide administrator).
///
/// There are two ways to create a node:
/// * Create a node with default configuration for the specified node type.
/// * Create and configure a node simultaneously.
///
/// ### Example:
/// ```xml
/// <iq type='set'
///     from='vsevex@example.com/mobile'
///     to='pubsub.example.com'
///     id='create1'>
///   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
///     <create node='somenode'/>
///   </pubsub>
/// </iq>
/// ```
/// see <https://xmpp.org/extensions/xep-0060.html#owner-create>
class PubSubCreate extends XMLBase {
  PubSubCreate({super.element, super.parent})
      : super(
          name: 'create',
          namespace: _$namespace,
          includeNamespace: false,
          pluginAttribute: 'create',
          interfaces: <String>{'node'},
        );

  @override
  PubSubCreate copy({xml.XmlElement? element, XMLBase? parent}) => PubSubCreate(
        element: element,
        parent: parent,
      );
}

/// This stanza will be used to get default subscription options for a node,
/// the ntity MUST send an empty __<default/>__ element to the node, in
/// response, the node SHOLD return the default options.
///
/// ### Example:
/// ```xml
/// <iq type='get'
///     from='vsevex@example.com/mobile'
///     to='pubsub.example.com'
///     id='def1'>
///   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
///     <default node='someNode'/>
///   </pubsub>
/// </iq>
/// ```
///
/// To get default subscription configuration options for all (leaf) nodes at a
/// service, the entity MUST send an empty <default/> element but not specify
/// a node; in response, the service SHOULD return the default subscription
/// options.
///
/// ```xml
/// <iq type='get'
///     from='vsevex@example.com/mobile'
///     to='pubsub.example.com'
///     id='def1'>
///   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
///     <default/>
///   </pubsub>
/// </iq>
/// ```
///
/// see <https://xmpp.org/extensions/xep-0060.html#subscribe-default>
class PubSubDefault extends XMLBase {
  PubSubDefault({super.getters, super.element, super.parent})
      : super(
          name: 'default',
          namespace: _$namespace,
          includeNamespace: false,
          pluginAttribute: 'default',
          interfaces: <String>{'node', 'type'},
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('type'): (args, base) => _type,
    });
  }

  String get _type {
    final type = getAttribute('type');
    if (type.isEmpty) {
      return 'leaf';
    }
    return type;
  }

  @override
  PubSubDefault copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubDefault(
        getters: getters,
        element: element,
        parent: parent,
      );
}

/// This stanza helps to support the ability to publish items. Any entity that
/// is allowed to publish items to node (i.e., a publisher or an owner) may do
/// so at any time by sending an IQ-set to the service containing a pubsub
/// element with a __<publish/>__ child.
///
/// * The <publish/> element MUST possess a `node` attribute, specifying the
/// NodeID of the node.
/// * Depending on the node configuration, the __<publish/>__ element MAY
/// contain no __<item/>__ elements or one __<item/>__ element.
///
/// see <https://xmpp.org/extensions/xep-0060.html#publisher-publish>
class PubSubPublish extends XMLBase {
  PubSubPublish({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.pluginIterables,
    super.element,
    super.parent,
  }) : super(
          name: 'publish',
          namespace: _$namespace,
          includeNamespace: false,
          pluginAttribute: 'publish',
          interfaces: <String>{'node'},
        ) {
    registerPlugin(PubSubItem(), iterable: true);
  }

  @override
  PubSubPublish copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubPublish(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        pluginIterables: pluginIterables,
        element: element,
        parent: parent,
      );
}

/// This retract stanzas will be send by the publisher to delete an item. The
/// __<retract/>__ element MUST possess a `node` attribute, MAY possess a
/// `notify` attribute, and MUST contain one __<item/>__ element; this item
/// element MUST be empty and MUST possess and `id` attribute.
///
/// ```xml
/// <iq type='set'
///     from='vsevex@example.com/mobile'
///     to='pubsub.example.com'
///     id='retract1'>
///   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
///     <retract node='someNode'>
///       <item id='ae890ac52d0df67ed7cfdf51b644e901'/>
///     </retract>
///   </pubsub>
/// </iq>
/// ```
class PubSubRetract extends XMLBase {
  PubSubRetract({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.getters,
    super.setters,
    super.element,
    super.parent,
  }) : super(
          name: 'retract',
          namespace: _$namespace,
          includeNamespace: false,
          pluginAttribute: 'retract',
          interfaces: <String>{'node', 'notify'},
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('notify'): (args, base) => _notify,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('notify'): (value, args, base) => _setNotify(value),
    });

    registerPlugin(PubSubItem());
  }

  bool? get _notify {
    final notify = getAttribute('notify');
    if (<String>{'0', 'false'}.contains(notify)) {
      return false;
    } else if (<String>{'1', 'true'}.contains(notify)) {
      return true;
    }
    return null;
  }

  void _setNotify(dynamic value) {
    delete('notify');
    if (value == null) {
      return;
    } else if (<dynamic>{true, '1', 'true', 'True'}.contains(value)) {
      setAttribute('notify', 'true');
    } else {
      setAttribute('notify', 'false');
    }
  }

  @override
  PubSubRetract copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubRetract(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
      );
}

/// Helps whenever the subscriber want to unsubscribe from a node. The subsriber
/// sends an IQ-set whose __<pubsub/>__ child contains __<unsubscribe/>__
/// element that specifies the node and the subscribed [JabberID].
///
/// ### Example:
/// ```xml
/// <iq type='set'
///     from='vsevex@example.com/mobile'
///     to='pubsub.example.com'
///     id='unsub1'>
///   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
///     <unsubscribe
///         node='someNode'
///         jid='vsevex@example.com'/>
///   </pubsub>
/// </iq>
/// ```
///
/// see <https://xmpp.org/extensions/xep-0060.html#subscriber-unsubscribe>
class PubSubUnsubscribe extends XMLBase {
  PubSubUnsubscribe({
    super.getters,
    super.setters,
    super.element,
    super.parent,
  }) : super(
          name: 'unsubscribe',
          namespace: _$namespace,
          includeNamespace: false,
          pluginAttribute: 'unsubscribe',
          interfaces: <String>{'node', 'jid', 'subid'},
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('jid'): (args, base) => _jid,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('jid'): (value, args, base) => _setJid(value as JabberID),
    });
  }

  JabberID get _jid => JabberID(getAttribute('jid'));

  void _setJid(JabberID jid) => setAttribute('jid', jid.toString());

  @override
  PubSubUnsubscribe copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubUnsubscribe(
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
      );
}

/// When an entity wishes to subscribe to a node, it sends a subscription
/// request to the pubsub service. The subscription request is an IQ-set where
/// the __<pubsub/>__ element contains one and only one __<subscribe/>__
/// element.
///
/// The __<subscribe/>__ element SHOULD possess a `node` attribute specifying
/// the node to which the entity wishes to subscribe. The __<subscribe/>__
/// element MUST also possess a `jid` attribute specifying the exact XMPP
/// address to be used as the subscribed JID -- often a bare JID
/// (<vsevex@example.com> or <example.com>) or full JID
/// (<vsevex@example.com/mobile>.
class PubSubSubscribe extends XMLBase {
  PubSubSubscribe({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.getters,
    super.setters,
    super.element,
    super.parent,
  }) : super(
          name: 'subscribe',
          namespace: _$namespace,
          includeNamespace: false,
          pluginAttribute: 'subscribe',
          interfaces: <String>{'node', 'jid'},
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('jid'): (args, base) => _jid,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('jid'): (value, args, base) => _setJid(value as JabberID),
    });

    registerPlugin(PubSubOptions());
  }

  JabberID get _jid => JabberID(getAttribute('jid'));

  void _setJid(JabberID jid) => setAttribute('jid', jid.toString());

  @override
  PubSubSubscribe copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubSubscribe(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
      );
}

/// The node creation may requrie to configure it. This stanza will come to help
/// whenever the publisher needs to configure the node.
///
/// ### Example:
/// ```xml
/// <iq type='get'
///     from='alyosha@example.com/dekstop'
///     to='pubsub.example.com'
///     id='config1'>
///   <pubsub xmlns='http://jabber.org/protocol/pubsub#owner'>
///     <configure node='someNode'/>
///   </pubsub>
/// </iq>
/// ```
class PubSubConfigure extends XMLBase {
  PubSubConfigure({
    String? namespace,
    super.interfaces = const <String>{'node', 'type'},
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.getters,
    super.element,
    super.parent,
  }) : super(
          name: 'configure',
          includeNamespace: false,
          pluginAttribute: 'configure',
        ) {
    this.namespace = namespace ?? _$namespace;
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('type'): (args, base) => _type,
    });

    registerPlugin(Form());
  }

  String get _type {
    final type = getAttribute('type');
    if (type.isEmpty) {
      return 'leaf';
    }
    return type;
  }

  @override
  PubSubConfigure copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubConfigure(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        getters: getters,
        element: element,
        parent: parent,
      );
}

/// This stanza is helpful when the subscriber want to request the subscription
/// options by including __<options/>__ element inside an IQ-get stanza.
///
/// ### Example:
/// ```xml
/// <iq type='get'
///     from='vsevex@example.com/mobile'
///     to='pubsub.example.com'
///     id='options1'>
///   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
///     <options node='someNode' jid='vsevex@example.com'/>
///   </pubsub>
/// </iq>
/// ```
///
/// see <https://xmpp.org/extensions/xep-0060.html#subscriber-configure>
class PubSubOptions extends XMLBase {
  PubSubOptions({
    super.getters,
    super.setters,
    super.deleters,
    super.element,
    super.parent,
  }) : super(
          name: 'options',
          namespace: _$namespace,
          includeNamespace: false,
          pluginAttribute: 'options',
          interfaces: <String>{'jid', 'node', 'options'},
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('jid'): (args, base) => _jid,
      const Symbol('options'): (args, base) => _options,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('jid'): (value, args, base) => _setJid(value as JabberID),
      const Symbol('options'): (value, args, base) => _setOptions(value),
    });

    addDeleters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('options'): (args, base) => _deleteOptions(),
    });
  }

  JabberID get _jid => JabberID(getAttribute('jid'));

  void _setJid(JabberID jid) => setAttribute('jid', jid.toString());

  Form get _options {
    final config =
        element!.getElement('x', namespace: WhixpUtils.getNamespace('FORMS'));
    return Form(element: config);
  }

  void _setOptions(dynamic value) {
    if (value is XMLBase) {
      element!.children.add(value.element!);
    } else if (value is xml.XmlElement) {
      element!.children.add(value);
    }
  }

  void _deleteOptions() {
    final config =
        element!.getElement('x', namespace: WhixpUtils.getNamespace('FORMS'));
    element!.children.remove(config);
  }

  @override
  PubSubOptions copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubOptions(
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}

/// A pubsub service MAY support the ability to specify options along with a
/// publish request.
///
/// The __<publish-options/>__ element MUST contain a data form (see XEP-0004).
///
/// ### Example:
/// ```xml
/// <iq type='set'
///     from='vsevex@example.com/desktop'
///     to='pubsub.example.com'
///     id='pub1'>
///   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
///     <publish node='someNode'>
///       <item id='ae890ac52d0df67ed7cfdf51b644e901'>
///         <entry xmlns='http://www.w3.org/2005/Atom'>
///           <title>Soliloquy</title>
///           <summary>
/// To be, or not to be: that is the question:
/// Whether 'tis nobler in the mind to suffer
/// The slings and arrows of outrageous fortune,
/// Or to take arms against a sea of troubles,
/// And by opposing end them?
///           </summary>
///           <link rel='alternate' type='text/html'
///                 href='http://denmark.lit/2003/12/13/atom03'/>
///           <id>tag:denmark.lit,2003:entry-32397</id>
///           <published>2003-12-13T18:30:02Z</published>
///           <updated>2003-12-13T18:30:02Z</updated>
///         </entry>
///       </item>
///     </publish>
///     <publish-options>
///       <x xmlns='jabber:x:data' type='submit'>
///         <field var='FORM_TYPE' type='hidden'>
///          <value>http://jabber.org/protocol/pubsub#publish-options</value>
///         </field>
///         <field var='pubsub#access_model'>
///           <value>presence</value>
///         </field>
///       </x>
///     </publish-options>
///   </pubsub>
/// </iq>
/// ```
class PubSubPublishOptions extends XMLBase {
  PubSubPublishOptions({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.getters,
    super.setters,
    super.deleters,
    super.element,
    super.parent,
  }) : super(
          name: 'publish-options',
          namespace: _$namespace,
          includeNamespace: false,
          pluginAttribute: 'publish_options',
          interfaces: <String>{'publish_options'},
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('publish_options'): (args, base) => _publishOptions,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('publish_options'): (value, args, base) =>
          _setPublishOptions(value),
    });

    addDeleters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('publish_options'): (args, base) => _deletePublishOptions(),
    });

    registerPlugin(Form());
  }

  Form? get _publishOptions {
    final config =
        element!.getElement('x', namespace: WhixpUtils.getNamespace('FORMS'));
    if (config == null) {
      return null;
    }
    final form = Form(element: config);
    return form;
  }

  void _setPublishOptions(dynamic value) {
    if (value == null) {
      _deletePublishOptions();
    } else {
      if (value is XMLBase) {
        element!.children.add(value.element!);
      } else if (value is xml.XmlElement) {
        element!.children.add(value);
      }
    }
  }

  void _deletePublishOptions() {
    final config =
        element!.getElement('x', namespace: WhixpUtils.getNamespace('FORMS'));
    if (config != null) {
      element!.children.remove(config);
    }
    parent!.element!.children.remove(element);
  }

  @override
  PubSubPublishOptions copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubPublishOptions(
        pluginAttributeMapping: pluginAttributeMapping,
        pluginTagMapping: pluginTagMapping,
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}
