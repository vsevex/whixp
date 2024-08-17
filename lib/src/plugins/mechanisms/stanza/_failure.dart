part of '../feature.dart';

/// Represents a failure packet.
///
/// This packet is used to indicate a failure in an operation.
class SASLFailure with Packet {
  /// Constructs a [SASLFailure] packet.
  const SASLFailure({this.reason, this.type, this.any});

  /// The reason for the failure.
  final String? reason;

  /// The type of failure.
  final String? type;

  /// Additional nodes associated with the failure.
  final Nodes? any;

  /// Constructs a [SASLFailure] packet from XML.
  factory SASLFailure.fromXML(xml.XmlElement node) {
    String? reason;
    String? type;

    for (final child in node.children.whereType<xml.XmlElement>()) {
      switch (child.localName) {
        case 'text':
          reason = child.innerText;
        case 'type':
          type = child.localName;
      }
    }
    final failure = SASLFailure(
      reason: reason,
      type: type,
      any: Nodes.fromXML(
        node.children
            .whereType<xml.XmlElement>()
            .map((node) => Node.fromXML(node))
            .toList(),
      ),
    );

    return failure;
  }

  @override
  xml.XmlElement toXML() {
    final element = WhixpUtils.xmlElement('failure', namespace: _namespace);
    if (any?.nodes.isNotEmpty ?? false) {
      for (final node in any!.nodes) {
        element.children.add(node.toXML().copy());
      }
    }

    return element;
  }

  @override
  String get name => _failure;
}
