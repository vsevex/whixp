part of '../feature.dart';

class SMFailed extends Stanza {
  /// Initializes a new instance of [SMFailed].
  const SMFailed({this.cause});

  /// The cause of the failure.
  final Node? cause;

  /// Creates an [SMFailed] instance from an XML element.
  ///
  /// [node] The XML element representing the SMFailed.
  factory SMFailed.fromXML(xml.XmlElement node) {
    Node? cause;

    for (final child in node.children.whereType<xml.XmlElement>()) {
      cause = Node.fromXML(child);
    }

    return SMFailed(cause: cause);
  }

  @override
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();
    final dictionary = HashMap<String, String>();
    dictionary['xmlns'] = _namespace;

    builder.element('failed', attributes: dictionary);

    final root = builder.buildDocument().rootElement;

    if (cause != null) root.children.add(cause!.toXML().copy());

    return root;
  }

  @override
  String get name => _failed;
}
