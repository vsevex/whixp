import 'package:meta/meta.dart';

import 'package:whixp/src/plugins/base.dart';
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
  Delay() : super('delay', description: 'XEP-0203: Delayed Delivery');

  @override
  void pluginInitialize() {}

  /// Do not import.
  @override
  void sessionBind(String? jid) {}

  /// Do not import.
  @override
  void pluginEnd() {}
}
