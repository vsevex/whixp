import 'package:whixp/src/_static.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/plugins/plugins.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

part 'stanza.dart';

/// The most common uses of this namespace are to stamp:
///
/// * A message that is sent to an offline entity and stored for later delivery.
/// * The last available presence stanza sent by a connected client to a server.
/// * Messages cached by a Multi-User Chat room for delivery to new participants
/// when they join the room.
///
/// ```xml
/// <message
///     from='vsevex@localhost/heh'
///     to='alyosha@example.com'
///     type='chat'>
///   <body>
///     O blessed, blessed night! I am afeard.
///     Being in night, all this is but a dream,
///     Too flattering-sweet to be substantial.
///   </body>
///   <delay xmlns='urn:xmpp:delay'
///      from='example.com'
///      stamp='2002-09-10T23:08:25Z'>
///     Offline Storage
///   </delay>
/// </message>
/// ```
///
/// see <https://xmpp.org/extensions/xep-0203.html>
class Delay {
  /// XMPP stanzas are sometimes withheld for delivery due to the receipent
  /// being offline, or are resent in order to establish recent history as is
  /// the case with MUCs. In any case, it is impoprtant to konw when the stanza
  /// was originally sent, not just when it was last received.
  ///
  /// ### Example:
  /// ```dart
  /// void main() {
  ///   final delay = Delay();
  ///   /// ...register this plugin in the Whixp instance.
  ///
  ///   addEventHandler<Message>('someEvent', (message) {
  ///     final delayedMessage = (message['delay'] as DelayStanza);
  ///     /// ...do whatever you need on this stanza.
  ///   });
  /// }
  /// ```
  ///
  /// The initialization of this plugin is not mandatory due the corresponding
  /// stanza for this plugin will be registered beforehand. So, you will only
  /// need to capture the incoming Message or Presence stanzas and parse delayed
  /// message by type casting.
  Delay() : super();

  late final _time = const DateTimeProfile();

  /// Gets timestamp from the provided [DelayStanza].
  DateTime? getStamp(DelayStanza stanza, {bool toLocal = false}) {
    final timestamp = stanza.stamp;
    if (timestamp?.isEmpty ?? true) return null;

    if (toLocal) return _time.parse(timestamp!).toLocal();
    return _time.parse(timestamp!);
  }

  /// Sets the provided [value] to the stanza as timestamp.
  String? convertToStamp(DateTime date) => _time.format(date.toUtc());
}
