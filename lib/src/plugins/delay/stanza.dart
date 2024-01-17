part of 'delay.dart';

@internal
class DelayStanza extends XMLBase {
  DelayStanza({super.element, super.parent})
      : super(
          name: 'delay',
          namespace: 'urn:xmpp:delay',
          pluginAttribute: 'delay',
          interfaces: {'from', 'stamp', 'text'},
        );

  @override
  DelayStanza copy({xml.XmlElement? element, XMLBase? parent}) => DelayStanza(
        element: element,
        parent: parent,
      );
}
