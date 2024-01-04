part of 'base.dart';

class StanzaBase extends XMLBase {
  StanzaBase({
    String? stanzaType,
    String? stanzaTo,
    String? stanzaFrom,
    String? stanzaID,
    this.types = const <String>{},
    super.name,
    super.namespace,
    super.transport,
    super.receive,
    super.pluginAttribute,
    super.pluginMultiAttribute,
    super.overrides,
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.interfaces,
    super.subInterfaces,
    super.boolInterfaces,
    super.languageInterfaces,
    super.pluginOverrides,
    super.pluginIterables,
    super.isExtension = false,
    super.includeNamespace = true,
    super.getters,
    super.setters,
    super.deleters,
    super.setupOverride,
    super.element,
    super.parent,
  }) {
    if (transport != null) {
      namespace = transport!.defaultNamespace;
    }

    if (stanzaType != null) {
      this['type'] = stanzaType;
    }
    if (stanzaTo != null) {
      this['to'] = JabberID(stanzaTo);
    }
    if (stanzaFrom != null) {
      this['from'] = JabberID(stanzaFrom);
    }
    if (stanzaID != null) {
      this['id'] = stanzaID;
    }

    addSetters({
      const Symbol('payload'): (value, args, base) =>
          setPayload([value as xml.XmlElement]),
    });

    addDeleters({const Symbol('payload'): (_, __) => deletePayload()});
  }

  late Set<String> types;

  /// Sets the stanza's `type` attribute.
  void setType(String value) {
    if (types.contains(value)) {
      element!.setAttribute('type', value);
    }
  }

  /// Returns the value of stanza's `to` attribute.
  JabberID get to => JabberID(getAttribute('to'));

  /// Set the default `to` attribute of the stanza according to the passed [to]
  /// value.
  void setTo(String to) => setAttribute('to', to);

  /// Returns the value of stanza's `from` attribute.
  JabberID get from => JabberID(getAttribute('from'));

  /// Set the default `to` attribute of the stanza according to the passed
  /// [frpm] value.
  void setFrom(String from) => setAttribute('from', from);

  /// Returns a [Iterable] of XML child elements.
  Iterable<xml.XmlElement> get payload => element!.childElements;

  /// Add [xml.XmlElement] content to the stanza.
  void setPayload(List<xml.XmlElement> values) {
    for (final value in values) {
      add(Tuple2(value, null));
    }
  }

  /// Remove the XML contents of the stanza.
  void deletePayload() => clear();

  /// Prepares the stanza for sending a reply.
  ///
  /// Swaps the `from` and `to` attributes.
  ///
  /// If [clear] is `true`, then also remove the stanza's contents to make room
  /// for the reply content.
  ///
  /// For client streams, the `from` attribute is removed.
  S reply<S extends StanzaBase>({required S copiedStanza, bool clear = true}) {
    final newStanza = copiedStanza;

    if (transport != null && transport!.isComponent) {
      newStanza['from'] = this['to'];
      newStanza['to'] = this['from'];
    } else {
      newStanza['to'] = this['from'];
      newStanza.delete('from');
    }
    if (clear) {
      newStanza.clear();
    }

    return newStanza;
  }

  /// Set the stanza's type to `error`.
  StanzaBase error() {
    this['type'] = 'error';
    return this;
  }

  /// Called if no handlers have been registered to process this stanza.
  ///
  /// Mean to be overridden.
  void unhandled([Transport? transport]) {
    return;
  }

  /// Handle exceptions thrown during stanza processing.
  ///
  /// Meant to be overridden.
  void exception(Exception excp) {
    /// TODO: replace with proper log
    print('Exception handled in $tag stanza: $excp');
  }

  void send() {
    if (transport != null) {
      transport!.send(this);
    } else {
      print('tried to send stanza without a stanza: $this');
    }
  }

  @override
  StanzaBase copy([
    xml.XmlElement? element,
    XMLBase? parent,
    bool receive = false,
  ]) =>
      StanzaBase(
        name: name,
        namespace: namespace,
        transport: transport,
        receive: receive,
        interfaces: _interfaces,
        pluginAttribute: pluginAttribute,
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: _pluginAttributeMapping,
        pluginMultiAttribute: _pluginMultiAttribute,
        overrides: _overrides,
        subInterfaces: _subInterfaces,
        boolInterfaces: _boolInterfaces,
        languageInterfaces: _languageInterfaces,
        pluginIterables: _pluginIterables,
        getters: _getters,
        setters: _setters,
        deleters: _deleters,
        isExtension: _isExtension,
        includeNamespace: _includeNamespace,
        setupOverride: setupOverride,
        element: element,
        parent: parent,
      );
}
