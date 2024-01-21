import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/plugins/time/time.dart';
import 'package:whixp/src/stream/base.dart';

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
class Delay extends PluginBase {
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
  Delay() : super('delay', description: 'XEP-0203: Delayed Delivery');

  late final DateTimeProfile? _time;

  /// Gets timestamp from the provided [DelayStanza].
  DateTime? getStamp(DelayStanza stanza) {
    if (_time == null) {
      Log.instance.warning(
        'In order to parse timestamp, you need to register XMPP Date and Time Profiles plugin',
      );
      return null;
    }

    final timestamp = stanza.getAttribute('stamp');
    if (timestamp.isEmpty) {
      return null;
    }
    return _time.parse(timestamp);
  }

  /// Sets the provided [value] to the stanza as timestamp.
  ///
  /// Provided [value] must be [DateTime] or [String].
  void setStamp(DelayStanza stanza, dynamic value) {
    assert(
      value is DateTime || value is String,
      'Provided value must be either DateTime or String',
    );

    if (_time == null) {
      Log.instance.warning(
        'In order to parse timestamp, you need to register XMPP Date and Time Profiles plugin',
      );
      return;
    }

    late String timestamp;

    if (value is DateTime) {
      timestamp = _time.format(value.toUtc());
    } else {
      timestamp = value as String;
    }

    stanza.setAttribute('stamp', timestamp);
  }

  @override
  void pluginInitialize() {
    _time = base.getPluginInstance<DateTimeProfile>('time');
  }

  /// Do not implement.
  @override
  void sessionBind(String? jid) {}

  /// Do not implement.
  @override
  void pluginEnd() {}
}
