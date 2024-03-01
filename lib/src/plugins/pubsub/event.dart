part of 'pubsub.dart';

/// ### Example:
/// ```xml
/// <message from='pubsub.example.com' to='vsevex@example.com' id='foo'>
///   <event xmlns='http://jabber.org/protocol/pubsub#event'>
///     <items node='someNode'>
///       <item id='ae890ac52d0df67ed7cfdf51b644e901'>
///         [ ... ENTRY ... ]
///       </item>
///     </items>
///   </event>
/// </message>
/// ```
class PubSubEvent extends XMLBase {
  PubSubEvent({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.element,
    super.parent,
  }) : super(
          name: 'event',
          namespace: _$event,
          pluginAttribute: 'pubsub_event',
          interfaces: <String>{},
        ) {
    registerPlugin(PubSubEventCollection());
    registerPlugin(PubSubEventConfiguration());
    registerPlugin(PubSubEventPurge());
    registerPlugin(PubSubEventDelete());
    registerPlugin(PubSubEventItems());
    registerPlugin(PubSubEventSubscription());
  }

  @override
  PubSubEvent copy({xml.XmlElement? element, XMLBase? parent}) => PubSubEvent(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        element: element,
        parent: parent,
      );
}

class PubSubEventItem extends XMLBase {
  PubSubEventItem({
    super.getters,
    super.setters,
    super.deleters,
    super.element,
    super.parent,
  }) : super(
          name: 'item',
          namespace: WhixpUtils.getNamespace('CLIENT'),
          includeNamespace: false,
          pluginAttribute: 'item',
          interfaces: <String>{'id', 'payload', 'node', 'publisher'},
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('payload'): (args, base) => _payload,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('payload'): (value, args, base) =>
          _setPayload(value as xml.XmlElement),
    });

    addDeleters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('payload'): (args, base) => _deletePayload(),
    });
  }

  void _setPayload(xml.XmlElement value) => element!.children.add(value.copy());

  xml.XmlElement? get _payload {
    if (element!.childElements.isNotEmpty) {
      return element!.childElements.first;
    }
    return null;
  }

  void _deletePayload() {
    for (final child in element!.children) {
      element!.children.remove(child);
    }
  }

  @override
  PubSubEventItem copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubEventItem(
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}

class PubSubEventItems extends XMLBase {
  PubSubEventItems({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.pluginIterables,
    super.element,
    super.parent,
  }) : super(
          name: 'items',
          namespace: _$event,
          includeNamespace: false,
          pluginAttribute: 'items',
          interfaces: <String>{'node'},
        ) {
    registerPlugin(PubSubEventItem(), iterable: true);
    registerPlugin(PubSubEventRetract(), iterable: true);
  }

  List<PubSubItem> get items {
    if (iterables.isNotEmpty) {
      return iterables
          .map((iterable) => PubSubItem(element: iterable.element))
          .toList();
    }
    return <PubSubItem>[];
  }

  @override
  PubSubEventItems copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubEventItems(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        pluginIterables: pluginIterables,
        element: element,
        parent: parent,
      );
}

class PubSubEventRetract extends XMLBase {
  PubSubEventRetract({super.element, super.parent})
      : super(
          name: 'retract',
          namespace: WhixpUtils.getNamespace('CLIENT'),
          includeNamespace: false,
          pluginAttribute: 'retract',
          interfaces: <String>{'id'},
        );

  @override
  PubSubEventRetract copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubEventRetract(element: element, parent: parent);
}

class PubSubEventCollection extends XMLBase {
  PubSubEventCollection({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.element,
    super.parent,
  }) : super(
          name: 'collection',
          namespace: _$event,
          includeNamespace: false,
          pluginAttribute: 'collection',
          interfaces: <String>{'node'},
        ) {
    registerPlugin(PubSubEventAssociate());
    registerPlugin(PubSubEventDisassociate());
  }

  @override
  PubSubEventCollection copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubEventCollection(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        element: element,
        parent: parent,
      );
}

class PubSubEventAssociate extends XMLBase {
  PubSubEventAssociate({super.element, super.parent})
      : super(
          name: 'associate',
          namespace: _$event,
          includeNamespace: false,
          pluginAttribute: 'associate',
          interfaces: <String>{'node'},
        );

  @override
  PubSubEventAssociate copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubEventAssociate(element: element, parent: parent);
}

class PubSubEventDisassociate extends XMLBase {
  PubSubEventDisassociate({super.element, super.parent})
      : super(
          name: 'disassociate',
          namespace: _$event,
          includeNamespace: false,
          pluginAttribute: 'disassociate',
          interfaces: <String>{'node'},
        );

  @override
  PubSubEventDisassociate copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubEventDisassociate(element: element, parent: parent);
}

class PubSubEventConfiguration extends XMLBase {
  PubSubEventConfiguration({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.element,
    super.parent,
  }) : super(
          name: 'configuration',
          namespace: _$event,
          includeNamespace: false,
          pluginAttribute: 'configuration',
          interfaces: <String>{'node'},
        ) {
    registerPlugin(Form());
  }

  @override
  PubSubEventConfiguration copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubEventConfiguration(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        element: element,
        parent: parent,
      );
}

class PubSubEventPurge extends XMLBase {
  PubSubEventPurge({super.element, super.parent})
      : super(
          name: 'purge',
          namespace: _$event,
          includeNamespace: false,
          pluginAttribute: 'purge',
          interfaces: <String>{'node'},
        );

  @override
  PubSubEventPurge copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubEventPurge(element: element, parent: parent);
}

class PubSubEventDelete extends XMLBase {
  PubSubEventDelete({
    super.getters,
    super.setters,
    super.deleters,
    super.element,
    super.parent,
  }) : super(
          name: 'delete',
          namespace: _$event,
          includeNamespace: false,
          pluginAttribute: 'delete',
          interfaces: <String>{'node', 'redirect'},
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('redirect'): (args, base) => _redirect,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('redirect'): (value, args, base) =>
          _setRedirect(value as String),
    });

    addDeleters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('redirect'): (args, base) => _deleteRedirect(),
    });
  }

  String get _redirect {
    final redirect = element!.getElement('redirect', namespace: namespace);
    if (redirect != null) {
      return redirect.getAttribute('uri') ?? '';
    }
    return '';
  }

  void _setRedirect(String uri) {
    delete('redirect');
    final redirect = WhixpUtils.xmlElement('redirect');
    redirect.setAttribute('uri', uri);
    element!.children.add(redirect);
  }

  void _deleteRedirect() {
    final redirect = element!.getElement('redirect', namespace: namespace);
    if (redirect != null) {
      element!.children.remove(redirect);
    }
  }

  @override
  PubSubEventDelete copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubEventDelete(
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}

class PubSubEventSubscription extends XMLBase {
  PubSubEventSubscription({
    super.getters,
    super.setters,
    super.element,
    super.parent,
  }) : super(
          name: 'subscription',
          namespace: _$event,
          includeNamespace: false,
          pluginAttribute: 'subscription',
          interfaces: <String>{
            'node',
            'expiry',
            'jid',
            'subid',
            'subscription',
          },
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('expiry'): (args, base) => _expiry,
      const Symbol('jid'): (args, base) => _jid,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('expiry'): (value, args, base) =>
          _setExpiry(value as String),
      const Symbol('jid'): (value, args, base) => _setJid(value as JabberID),
    });
  }

  String get _expiry {
    final expiry = getAttribute('expiry');
    if (expiry.toLowerCase() == 'presence') {
      return expiry;
    }

    /// TODO: parse date
    return '';
  }

  void _setExpiry(String value) => setAttribute('expiry', value);

  JabberID? get _jid {
    final jid = getAttribute('jid');
    if (jid.isEmpty) {
      return null;
    }
    return JabberID(jid);
  }

  void _setJid(JabberID jid) => setAttribute('jid', jid.toString());

  @override
  PubSubEventSubscription copy({xml.XmlElement? element, XMLBase? parent}) =>
      PubSubEventSubscription(
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
      );
}
