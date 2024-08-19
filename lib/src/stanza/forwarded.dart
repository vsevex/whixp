import 'package:whixp/src/_static.dart';
import 'package:whixp/src/plugins/delay/delay.dart';
import 'package:whixp/src/stanza/message.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// There are many situations is which an entity needs to forward a previously
/// sent stanza to another entity, such as forwarding an interesting message to
/// a friend, or a server forwarding stored messages from an archive. Here we
/// specify a simple encapsulation method for such forwards.
class Forwarded extends MessageStanza {
  const Forwarded({this.delay, this.actual});

  /// It should be possible to annotate the stanza (e.g. with a timestamp)
  /// without ambiguity as to the original stanza contents.
  final DelayStanza? delay;

  /// * The original sender and receiver should be identified.
  /// * Most extension payloads should be included (not only a message <body/>).
  final Message? actual;

  @override
  xml.XmlElement toXML() {
    final element =
        WhixpUtils.xmlElement(name, namespace: 'urn:xmpp:forward:0');

    if (delay != null) element.children.add(delay!.toXML().copy());
    if (actual != null) element.children.add(actual!.toXML().copy());

    return element;
  }

  factory Forwarded.fromXML(xml.XmlElement node) {
    DelayStanza? delay;
    Message? message;

    for (final child in node.children.whereType<xml.XmlElement>()) {
      if (child.localName == 'delay') {
        delay = DelayStanza.fromXML(child);
      } else if (child.localName == 'message') {
        message = Message.fromXML(child);
      }
    }

    return Forwarded(delay: delay, actual: message);
  }

  @override
  String get name => 'forwarded';

  @override
  String get tag => forwardedTag;
}
