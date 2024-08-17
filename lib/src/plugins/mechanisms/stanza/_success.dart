part of '../feature.dart';

/// Represents a success packet.
///
/// This packet is used to indicate a successful operation.
class SASLSuccess with Packet {
  /// Constructs a [SASLSuccess] packet.
  const SASLSuccess({this.body});

  /// The body of the success message.
  final String? body;

  /// Constructs a [SASLSuccess] packet from XML.
  factory SASLSuccess.fromXML(xml.XmlElement node) {
    final success = SASLSuccess(body: node.innerText);

    return success;
  }

  @override
  xml.XmlElement toXML() {
    final element = WhixpUtils.xmlElement('success', namespace: _namespace);
    if (body != null) element.children.add(xml.XmlText(body!).copy());

    return element;
  }

  @override
  String get name => _success;
}
