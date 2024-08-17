part of '../feature.dart';

/// Represents a challenge packet.
///
/// This packet is used to send a challenge during an authentication process.
class SASLChallenge with Packet {
  /// Constructs a [SASLChallenge] packet.
  const SASLChallenge({this.body});

  /// The body of the challenge.
  final String? body;

  /// Constructs a [SASLChallenge] packet from XML.
  factory SASLChallenge.fromXML(xml.XmlElement node) =>
      SASLChallenge(body: WhixpUtils.atob(node.innerText));

  @override
  xml.XmlElement toXML() {
    final element = WhixpUtils.xmlElement('challenge', namespace: _namespace);
    if (body?.isNotEmpty ?? false) {
      element.children.add(xml.XmlText(body!).copy());
    }

    return element;
  }

  @override
  String get name => _challenge;
}
