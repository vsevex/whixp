part of '../feature.dart';

class SMRequest extends Stanza {
  const SMRequest();

  @override
  xml.XmlElement toXML() => WhixpUtils.xmlElement('r', namespace: _namespace);

  @override
  String get name => _request;
}
