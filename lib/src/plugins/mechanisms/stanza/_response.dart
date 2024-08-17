part of '../feature.dart';

/// Represents a response packet.
///
/// This packet is used to send a response during an authentication process.
class SASLResponse with Packet {
  /// Constructs a [SASLResponse] packet.
  const SASLResponse({this.body});

  /// The body of the response.
  final String? body;

  /// Constructs a [SASLResponse] packet from XML.
  factory SASLResponse.fromXML(xml.XmlElement node) =>
      SASLResponse(body: node.innerText);

  @override
  xml.XmlElement toXML() {
    final element = WhixpUtils.xmlElement('response', namespace: _namespace);

    element.children.add(
      xml.XmlText((body?.isNotEmpty ?? false) ? WhixpUtils.btoa(body!) : '=')
          .copy(),
    );

    return element;
  }

  @override
  String get name => _response;
}
