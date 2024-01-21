part of 'delay.dart';

class DelayStanza extends XMLBase {
  DelayStanza({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.getters,
    super.setters,
    super.element,
    super.parent,
  }) : super(
          name: 'delay',
          namespace: 'urn:xmpp:delay',
          pluginAttribute: 'delay',
          interfaces: {'from', 'stamp', 'text'},
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('from'): (args, base) => from,
      const Symbol('text'): (args, base) => text,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('from'): (value, args, base) => setFrom(value as JabberID),
      const Symbol('text'): (value, args, base) => text = value as String,
    });
  }

  JabberID? get from {
    final jid = getAttribute('from');
    if (jid.isNotEmpty) {
      return JabberID(jid);
    }
    return null;
  }

  void setFrom(JabberID jid) => setAttribute('from', jid.toString());

  String get text => element!.innerText;

  set text(String value) => element!.innerText = value;

  @override
  DelayStanza copy({xml.XmlElement? element, XMLBase? parent}) => DelayStanza(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
      );
}
