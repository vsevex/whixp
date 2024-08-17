import "package:whixp/src/exception.dart";
import "package:whixp/src/plugins/features.dart";
import "package:whixp/src/stanza/error.dart";
import "package:whixp/src/stanza/iq.dart";
import "package:whixp/src/stanza/message.dart";
import "package:whixp/src/stanza/mixins.dart";
import "package:whixp/src/stanza/presence.dart";
import "package:whixp/src/utils/utils.dart";

import "package:xml/xml.dart" as xml;

// ignore: avoid_classes_with_only_static_members
/// A utility class for parsing XML elements and decoding them into
/// corresponding XMPP stanzas.
class XMLParser {
  /// Constructs an instance of [XMLParser].
  const XMLParser();

  /// Decodes the next XMPP packet based on the provided XML element and
  /// namespace.
  ///
  /// If [namespace] is not provided, the default namespace for XMPP client is
  /// used. Throws a [WhixpInternalException] if the namespace is unknown.
  static Packet nextPacket(xml.XmlElement node, {String? namespace}) {
    final ns =
        node.namespaceUri ?? namespace ?? WhixpUtils.getNamespace('CLIENT');
    switch (ns) {
      case 'jabber:client':
        return _decodeClient(node);
      case 'http://etherx.jabber.org/streams':
        return _decodeStream(node);
      case 'urn:ietf:params:xml:ns:xmpp-sasl':
        return _decodeSASL(node);
      case 'urn:xmpp:sm:3':
        return StreamManagement.parse(node);
      default:
        throw WhixpInternalException.unknownNamespace(ns);
    }
  }

  /// Decodes an XMPP packet from the 'urn:ietf:params:xml:ns:xmpp-streams'
  /// namespace.
  ///
  /// Throws a [WhixpInternalException] if the XML element's local name does
  /// not match expected packets.
  static Packet _decodeStream(xml.XmlElement node) {
    switch (node.localName) {
      case 'error':
        return ErrorStanza.fromXML(node);
      case 'features':
        return StreamFeatures.fromXML(node);
      default:
        throw WhixpInternalException.unexpectedPacket(
          node.getAttribute('xmlns'),
          node.localName,
        );
    }
  }

  /// Decodes an XMPP packet from the 'jabber:client' namespace.
  ///
  /// Throws a [WhixpInternalException] if the XML element's local name does
  /// not match expected packets.
  static Packet _decodeClient(xml.XmlElement node) {
    switch (node.localName) {
      case 'message':
        return Message.fromXML(node);
      case 'presence':
        return Presence.fromXML(node);
      case 'iq':
        return IQ.fromXML(node);
      default:
        throw WhixpInternalException.unexpectedPacket(
          node.namespaceUri,
          node.localName,
        );
    }
  }

  static Packet _decodeSASL(xml.XmlElement node) {
    switch (node.localName) {
      case 'challenge':
        return SASLChallenge.fromXML(node);
      case 'response':
        return SASLResponse.fromXML(node);
      case 'success':
        return SASLSuccess.fromXML(node);
      case 'failure':
        return SASLFailure.fromXML(node);
      default:
        throw WhixpInternalException.unexpectedPacket(
          node.namespaceUri,
          node.localName,
        );
    }
  }
}
