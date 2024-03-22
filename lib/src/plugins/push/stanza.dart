part of 'push.dart';

class _EnablePush extends XMLBase {
  _EnablePush({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.element,
    super.parent,
  }) : super(
          name: 'enable',
          namespace: 'urn:xmpp:push:0',
          pluginAttribute: 'enable',
          interfaces: <String>{'node', 'jid'},
        ) {
    registerPlugin(Form());
  }

  @override
  _EnablePush copy({xml.XmlElement? element, XMLBase? parent}) {
    return _EnablePush(
      pluginTagMapping: pluginTagMapping,
      pluginAttributeMapping: pluginTagMapping,
      element: element,
      parent: parent,
    );
  }
}

class _DisablePush extends XMLBase {
  _DisablePush({
    super.element,
    super.parent,
  }) : super(
          name: 'disable',
          namespace: 'urn:xmpp:push:0',
          pluginAttribute: 'disable',
          interfaces: <String>{'node', 'jid'},
        );

  @override
  _DisablePush copy({xml.XmlElement? element, XMLBase? parent}) {
    return _DisablePush(element: element, parent: parent);
  }
}
