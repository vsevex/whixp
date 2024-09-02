part of 'markers.dart';

class _MarkerStanza extends Stanza {
  @override
  xml.XmlElement toXML() => WhixpUtils.xmlElement(
        name,
        namespace: WhixpUtils.getNamespace('MARKERS'),
      );

  @override
  String get name => 'markable';
}

class _DisplayedStanza extends Stanza {
  const _DisplayedStanza(this.messageID);

  final String messageID;

  @override
  xml.XmlElement toXML() => WhixpUtils.xmlElement(
        name,
        namespace: WhixpUtils.getNamespace('MARKERS'),
        attributes: <String, String>{'id': messageID},
      );

  @override
  String get name => 'displayed';
}
