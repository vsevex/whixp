import 'package:whixp/src/exception.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/stanza/node.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// Represents an error stanza in XMPP.
class ErrorStanza extends Stanza {
  /// Holds the name of the error stanza.
  static const String _name = 'error';

  ErrorStanza();

  /// Returns the error code of the stanza.
  int? code;

  /// Returns the type of the error. The type is an attribute of the stanza that
  /// identifies the category of the error.
  String? type;

  /// Returns the reason for the error. Attribute of the stanza that provides a
  /// human-readable explanation of the error.
  String? reason;

  /// Attribute of the stanza that provides additional information about the
  /// error.
  String? text;

  /// Creates an instance of the stanza from a string.
  factory ErrorStanza.fromString(String stanza) {
    try {
      final root = xml.XmlDocument.parse(stanza);
      return ErrorStanza.fromXML(root.rootElement);
    } catch (_) {
      throw WhixpInternalException.invalidXML();
    }
  }

  /// Overrides of the `toXML` method that returns an XML representation of the
  /// stanza.
  @override
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();
    final dictionary = <String, String>{};

    if (type != null) dictionary['type'] = type!;
    if (code != null && code != 0) dictionary['code'] = code!.toString();
    dictionary.addAll({
      'xmlns': 'urn:ietf:params:xml:ns:xmpp-stanzas',
    });

    builder.element(
      _name,
      attributes: dictionary,
      nest: () {
        if (reason?.isNotEmpty ?? false) {
          builder.element('reason', nest: () => builder.text(reason!));
        }
        if (text?.isNotEmpty ?? false) {
          builder.element('text', nest: () => builder.text(text!));
        }
      },
    );

    return builder.buildDocument().rootElement;
  }

  /// Creates an instance of the stanza from an XML node.
  factory ErrorStanza.fromXML(xml.XmlElement node) {
    if (node.localName != _name) {
      throw WhixpInternalException.invalidNode(node.localName, _name);
    }

    final error = ErrorStanza();

    for (final attribute in node.attributes) {
      switch (attribute.localName) {
        case "code":
          final innerText = attribute.value;
          if (innerText.isNotEmpty) {
            error.code = innerText.isNotEmpty ? int.parse(innerText) : 0;
          }
        case "type":
          final innerText = attribute.value;
          error.type = innerText.isNotEmpty ? innerText : null;
        default:
          break;
      }
    }

    for (final child in node.children.whereType<xml.XmlElement>()) {
      if (child.localName == "text") {
        error.text = child.innerText;
      } else {
        error.reason = child.localName;
      }
    }
    return error;
  }

  @override
  String get name => _name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ErrorStanza &&
          runtimeType == other.runtimeType &&
          code == other.code &&
          type == other.type &&
          reason == other.reason &&
          text == other.text;

  @override
  int get hashCode =>
      code.hashCode ^ type.hashCode ^ reason.hashCode ^ text.hashCode;
}

/// Represents an error in the XMPP stream.
class StreamError with Packet {
  static const String _name = 'error';
  static const String _namespace = 'http://etherx.jabber.org/streams';

  StreamError();

  /// The specific error node associated with the stream error.
  Node? error;

  /// If the error is `see-other-host`.
  bool seeOtherHost = false;

  /// The error text message, if available.
  String? text;

  /// Constructs a [StreamError] instance from the given XML [node].
  factory StreamError.fromXML(xml.XmlElement node) {
    final error = StreamError();

    for (final child in node.children.whereType<xml.XmlElement>()) {
      if (child.localName == 'see-other-host') {
        error.seeOtherHost = true;
        error.text = child.innerText;
      }
      if (child.localName == 'text' &&
          child.namespaceUri == 'urn:ietf:params:xml:ns:xmpp-streams') {
        error.text = child.innerText;
      } else {
        error.error = Node.fromXML(child);
      }
    }

    return error;
  }

  @override
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();

    builder.element(_name, attributes: <String, String>{'xmlns': _namespace});
    if (text?.isNotEmpty ?? false) {
      builder.element('text', nest: () => builder.text(text!));
    }

    final root = builder.buildDocument().rootElement;

    if (error != null) root.children.add(error!.toXML().copy());

    return root;
  }

  @override
  String get name => 'stream:error';
}
