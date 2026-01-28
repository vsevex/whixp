import 'dart:async' as async;

import 'package:whixp/src/_static.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/plugins/form/form.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/transport.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

part 'stanza.dart';

/// Provides static methods to enable and disable push notifications for a
/// specific Jabber ID (JID) and node.
class Push {
  const Push();

  /// Enables push notifications for the specified [jid] and [node].
  ///
  /// If [node] is not provided, then unique one will be created and will be
  /// returned to the user.
  static String enableNotifications(
    JabberID jid, {
    String? node,
    Form? payload,
    required Transport transport,
  }) {
    final nod = node ?? WhixpUtils.generateUniqueID('push');
    final iq = IQ(generateID: true)
      ..type = iqTypeSet
      ..payload = Enable(jid, nod, payload: payload);

    iq.send(transport);

    return nod;
  }

  /// Disables push notifications for the specified [jid] and optional [node].
  static async.FutureOr<IQ> disableNotifications(
    JabberID jid, {
    String? node,
    required Transport transport,
  }) {
    final iq = IQ(generateID: true)
      ..type = iqTypeSet
      ..payload = Disable(jid, node: node);

    return iq.send(transport);
  }
}
