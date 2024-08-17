part of 'delay.dart';

class DelayStanza extends MessageStanza {
  const DelayStanza(this.from, this.stamp, this.text);

  final JabberID? from;
  final String? stamp;
  final String? text;

  @override
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();
    final attributes = <String, String>{};

    if (from != null) attributes['from'] = from.toString();
    if (stamp?.isNotEmpty ?? false) attributes['stamp'] = stamp!;

    builder.element(
      name,
      attributes: <String, String>{'xmlns': 'urn:xmpp:delay'}
        ..addAll(attributes),
      nest: () {
        if (text?.isNotEmpty ?? false) builder.text(text!);
      },
    );

    return builder.buildDocument().rootElement;
  }

  factory DelayStanza.fromXML(xml.XmlElement node) {
    JabberID? jid;
    String? stamp;

    for (final attribute in node.attributes) {
      switch (attribute.localName) {
        case 'from':
          jid = JabberID(attribute.value);
        case 'stamp':
          stamp = attribute.value;
        default:
          break;
      }
    }

    return DelayStanza(jid, stamp, node.innerText);
  }

  @override
  String get name => 'delay';

  @override
  String get tag => delayTag;
}
