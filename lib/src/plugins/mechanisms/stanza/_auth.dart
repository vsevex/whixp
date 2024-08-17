part of '../feature.dart';

/// Represents an authentication packet.
///
/// This packet is used for authentication in the Simple Authentication and
/// Security Layer (SASL).
class _Auth with Packet {
  static const String _name = 'auth';

  /// Constructs an [_Auth] packet.
  const _Auth({this.mechanism, this.body});

  /// The authentication mechanism.
  final String? mechanism;

  /// The authentication body.
  final String? body;

  @override
  xml.XmlElement toXML() {
    final dictionary = HashMap<String, String>();
    dictionary['xmlns'] = _namespace;
    if (mechanism?.isNotEmpty ?? false) dictionary['mechanism'] = mechanism!;

    final element = WhixpUtils.xmlElement(_name, attributes: dictionary);
    if (body != null) element.children.add(xml.XmlText(body!).copy());

    return element;
  }

  @override
  String get name => 'sasl:$_name';
}
