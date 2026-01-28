import 'package:whixp/src/stanza/message.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

part 'stanza.dart';

extension Markable on Message {
  /// An entity interested to know if the recipient has displayed a message
  /// attaches a markable element qualified by dedicated namespace to the
  /// message.
  ///
  /// ### Example:
  /// ```xml
  /// <message to='vsevex@capulet.lit' from='alyosha@montegue.lit/mobile' id='message-id'>
  ///   <body>Zdarova.</body>
  ///   <markable xmlns='urn:xmpp:chat-markers:0'/>
  /// </message>
  /// ```
  ///
  Message get makeMarkable {
    addPayload(_MarkerStanza());
    return this;
  }

  /// To let the sender know a message has been displayed an entity sends a
  /// message with a displayed element. The displayed element must have a
  /// [messageID] attribute that copies the value from the 'message-id' attribute
  /// of the message it refers to.
  ///
  /// ### Example:
  /// ```xml
  /// <message to='vsevex@localhost' from='alyosha@localhost/desktop'>
  ///   <displayed xmlns='urn:xmpp:chat-markers:0' id='some-message-id'/>
  /// </message>
  /// ```
  Message makeDisplayed(String messageID) {
    addPayload(_DisplayedStanza(messageID));
    return this;
  }
}
