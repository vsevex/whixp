import 'package:whixp/src/exception.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// XMPP's <presence> stanza allows entities to know the status of other clients
/// and components. Since it is currently the only multi-cast stanza in XMPP,
/// many extensions and more information to [Presence] stanzas to broadcast
/// to every entry in the roster, such as capabilities, music choices, or
/// locations.
///
/// Since [Presence] stanzas are broadcast when an XMPP entity changes its
/// status, the bulk of the traffic in an XMP network will be from <presence>
/// stanazas. Therefore, do not include more information than necessary in a
/// status message or within a [Presence] stanza in order to help keep the
/// network running smoothly.
///
/// ### Example:
/// ```xml
/// <presence from="vsevex@example.com">
/// <show>away</show>
///   <status>old, but platin</status>
///   <priority>1</priority>
/// </presence>
/// ```
class Presence extends Stanza with Attributes {
  static const String _name = "presence";

  /// Constructs a presence stanza.
  Presence({this.show, this.status, this.nick, this.priority, this.error});

  /// The current presence show information.
  final String? show;

  /// The status message associated with the presence.
  final String? status;

  /// The nick associated with the presence.
  final String? nick;

  /// The priority of the presence.
  final int? priority;

  /// Error stanza associated with this presence stanza, if any.
  final ErrorStanza? error;

  /// List of payloads associated with this presence stanza.
  final payloads = <Stanza>[];

  /// Constructs a presence stanza from a string representation.
  ///
  /// Throws [WhixpInternalException] if the input XML is invalid.
  factory Presence.fromString(String stanza) {
    try {
      final doc = xml.XmlDocument.parse(stanza);
      final root = doc.rootElement;

      return Presence.fromXML(root);
    } catch (_) {
      throw WhixpInternalException.invalidXML();
    }
  }

  /// Constructs a presence stanza from an XML element node.
  ///
  /// Throws [WhixpInternalException] if the provided XML node is invalid.
  factory Presence.fromXML(xml.XmlElement node) {
    if (node.localName != _name) {
      throw WhixpInternalException.invalidNode(node.localName, _name);
    }

    String? show;
    String? status;
    int? priority;
    String? nick;
    ErrorStanza? error;
    final payloads = <Stanza>[];

    for (final child in node.children.whereType<xml.XmlElement>()) {
      switch (child.localName) {
        case 'show':
          show = child.innerText;
        case 'status':
          status = child.innerText;
        case 'priority':
          priority = int.parse(child.innerText);
        case 'nick':
          nick = child.innerText;
        case 'error':
          error = ErrorStanza.fromXML(child);
        default:
          try {
            final tag = WhixpUtils.generateNamespacedElement(child);

            payloads.add(Stanza.payloadFromXML(tag, child));
          } catch (ex) {
            // XMPPLogger.warn(ex);
          }
          break;
      }
    }

    final presence = Presence(
      show: show,
      status: status,
      nick: nick,
      priority: priority,
      error: error,
    )..payloads.addAll(payloads);
    presence.loadAttributes(node);

    return presence;
  }

  /// Converts the presence stanza to its XML representation.
  @override
  xml.XmlElement toXML() {
    final dict = attributeHash;
    final builder = WhixpUtils.makeGenerator();

    builder.element(
      _name,
      attributes: dict,
      nest: () {
        if (show?.isNotEmpty ?? false) {
          builder.element('show', nest: () => builder.text(show!));
        }
        if (status?.isNotEmpty ?? false) {
          builder.element('status', nest: () => builder.text(status!));
        }
        if (nick?.isNotEmpty ?? false) {
          builder.element('nick', nest: () => builder.text(nick!));
        }
        if (priority != null && priority != 0) {
          builder.element(
            'priority',
            nest: () => builder.text(priority.toString()),
          );
        }
      },
    );

    final root = builder.buildDocument().rootElement;

    if (error != null) root.children.add(error!.toXML().copy());

    return root;
  }

  /// Gets the payload of a specific type from the presence stanza.
  PresenceStanza? get<P extends PresenceStanza>() =>
      payloads.firstWhere((payload) => payload is P) as PresenceStanza?;

  /// Returns the name of the presence stanza.
  @override
  String get name => _name;
}
