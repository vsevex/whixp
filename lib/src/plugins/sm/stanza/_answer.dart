part of '../feature.dart';

/// Represents an answer in the state machine, incorporating packet
/// functionality.
class SMAnswer extends Stanza {
  /// Initializes a new instance of [SMAnswer].
  const SMAnswer({this.h});

  /// The value of 'h' attribute.
  final int? h;

  /// Creates an [SMAnswer] instance from an XML element.
  ///
  /// [node] The XML element representing the SMAnswer.
  factory SMAnswer.fromXML(xml.XmlElement node) {
    int? h;
    for (final attribute in node.attributes) {
      if (attribute.localName == 'h') h = int.parse(attribute.value);
    }

    return SMAnswer(h: h);
  }

  @override
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();
    final dictionary = <String, String>{};
    dictionary['xmlns'] = _namespace;

    if (h != null) dictionary['h'] = h.toString();

    builder.element('a', attributes: dictionary);

    return builder.buildDocument().rootElement;
  }

  @override
  String get name => _answer;
}
