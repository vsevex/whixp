part of 'sm.dart';

class Enable extends StanzaBase {
  Enable({
    super.getters,
    super.setters,
    super.element,
    super.parent,
    super.transport,
  }) : super(
          name: 'enable',
          namespace: 'urn:xmpp:sm:3',
          interfaces: <String>{'max', 'resume'},
        ) {
    addGetters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('resume'): (args, base) => resume,
    });

    addSetters(<Symbol,
        void Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('resume'): (value, args, base) => resume = value as bool,
    });
  }

  bool get resume =>
      {'true', '1'}.contains(getAttribute('resume', 'false').toLowerCase());

  set resume(bool value) {
    deleteAttribute('resume');
    setAttribute('resume', value ? 'true' : 'false');
  }

  @override
  Enable copy({
    xml.XmlElement? element,
    XMLBase? parent,
    bool receive = false,
  }) =>
      Enable(
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
        transport: transport,
      );
}

class Enabled extends StanzaBase {
  Enabled({super.getters, super.setters, super.element, super.parent})
      : super(
          name: 'enabled',
          namespace: 'urn:xmpp:sm:3',
          interfaces: <String>{'id', 'location', 'max', 'resume'},
        ) {
    addGetters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('resume'): (args, base) => resume,
    });

    addSetters(<Symbol,
        void Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('resume'): (value, args, base) => resume = value as bool,
    });
  }

  bool get resume =>
      {'true', '1'}.contains(getAttribute('resume', 'false').toLowerCase());

  set resume(bool value) {
    deleteAttribute('resume');
    setAttribute('resume', value ? 'true' : 'false');
  }

  @override
  Enabled copy({
    xml.XmlElement? element,
    XMLBase? parent,
    bool receive = false,
  }) =>
      Enabled(
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
      );
}

class Resume extends StanzaBase {
  Resume({
    super.getters,
    super.setters,
    super.element,
    super.parent,
    super.transport,
  }) : super(
          name: 'resume',
          namespace: 'urn:xmpp:sm:3',
          interfaces: <String>{'h', 'previd'},
        ) {
    addGetters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('h'): (args, base) => h,
    });

    addSetters(<Symbol,
        void Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('h'): (value, args, base) => h = value as int,
    });
  }

  int? get h {
    final h = getAttribute('h');
    if (h.isNotEmpty) {
      return int.parse(h);
    }
    return null;
  }

  set h(int? value) => setAttribute('h', value.toString());

  @override
  Resume copy({
    xml.XmlElement? element,
    XMLBase? parent,
    bool receive = false,
  }) =>
      Resume(
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
        transport: transport,
      );
}

class Resumed extends StanzaBase {
  Resumed({super.getters, super.setters, super.element, super.parent})
      : super(
          name: 'resumed',
          namespace: 'urn:xmpp:sm:3',
          interfaces: <String>{'h', 'previd'},
        ) {
    addGetters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('h'): (args, base) => h,
    });

    addSetters(<Symbol,
        void Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('h'): (value, args, base) => h = value as int,
    });
  }

  int? get h {
    final h = getAttribute('h');
    if (h.isNotEmpty) {
      return int.parse(h);
    }
    return null;
  }

  set h(int? value) => setAttribute('h', value.toString());

  @override
  Resumed copy({
    xml.XmlElement? element,
    XMLBase? parent,
    bool receive = false,
  }) =>
      Resumed(
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
      );
}

class Failed extends StanzaBase {
  Failed({super.element, super.parent})
      : super(
          name: 'failed',
          namespace: 'urn:xmpp:sm:3',
          interfaces: <String>{},
        );

  @override
  Failed copy({
    xml.XmlElement? element,
    XMLBase? parent,
    bool receive = false,
  }) =>
      Failed(element: element, parent: parent);
}

class RequestAck extends StanzaBase {
  RequestAck({super.element, super.parent})
      : super(name: 'r', namespace: 'urn:xmpp:sm:3', interfaces: <String>{});

  @override
  RequestAck copy({
    xml.XmlElement? element,
    XMLBase? parent,
    bool receive = false,
  }) =>
      RequestAck(element: element, parent: parent);
}

class Ack extends StanzaBase {
  Ack({super.getters, super.setters, super.element, super.parent})
      : super(
          name: 'a',
          namespace: 'urn:xmpp:sm:3',
          interfaces: <String>{'h'},
        ) {
    addGetters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('h'): (args, base) => h,
    });

    addSetters(<Symbol,
        void Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('h'): (value, args, base) => h = value as int,
    });
  }

  int? get h {
    final h = getAttribute('h');
    if (h.isNotEmpty) {
      return int.parse(h);
    }
    return null;
  }

  set h(int? value) => setAttribute('h', value.toString());

  @override
  Ack copy({
    xml.XmlElement? element,
    XMLBase? parent,
    bool receive = false,
  }) =>
      Ack(
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
      );
}

class StreamManagementStanza extends StanzaBase {
  StreamManagementStanza({
    super.getters,
    super.setters,
    super.deleters,
    super.element,
    super.parent,
  }) : super(
          name: 'sm',
          namespace: 'urn:xmpp:sm:3',
          pluginAttribute: 'sm',
          interfaces: <String>{'required', 'optional'},
        ) {
    addGetters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('required'): (args, base) => required,
      const Symbol('optional'): (args, base) => optional,
    });

    addSetters(<Symbol,
        void Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('required'): (value, args, base) => required = value as bool,
      const Symbol('optional'): (value, args, base) => optional = value as bool,
    });

    addDeleters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('required'): (args, base) => deleteRequired(),
      const Symbol('optional'): (args, base) => deleteOptional(),
    });
  }

  bool get required =>
      element!.getElement('required', namespace: namespace) != null;

  set required(bool value) {
    delete('required');
    if (value) {
      setSubText('required', text: '', keep: true);
    }
  }

  void deleteRequired() => deleteSub('required');

  bool get optional =>
      element!.getElement('optional', namespace: namespace) != null;

  set optional(bool value) {
    delete('optional');
    if (value) {
      setSubText('optional', text: '', keep: true);
    }
  }

  void deleteOptional() => deleteSub('optional');

  @override
  StreamManagementStanza copy({
    xml.XmlElement? element,
    XMLBase? parent,
    bool receive = false,
  }) =>
      StreamManagementStanza(
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}

extension XMLElementTag on xml.XmlElement {
  String get tag => '{${getAttribute('xmlns')}}${name.qualified}';
}
