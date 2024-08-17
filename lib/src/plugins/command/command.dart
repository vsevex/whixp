import 'dart:async' as async;

import 'package:whixp/src/_static.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

// part '_database.dart';
part 'stanza.dart';

// const _commandTable = 'commands';

// typedef _Handler = FutureOr<dynamic> Function(
//   IQ iq,
//   Map<String, dynamic>? session, [
//   dynamic results,
// ]);

// ignore: avoid_classes_with_only_static_members
///  XMPP's Adhoc Commands provides a generic workflow mechanism for interacting
/// with applications.
///
/// see <http://xmpp.org/extensions/xep-0050.html>
class AdHocCommands {
  const AdHocCommands();

  static final Map<String, Map<String, dynamic>> _sessions =
      <String, Map<String, dynamic>>{};

  /// Creates and sends a command stanza.
  ///
  /// If [flow] is true, the process the Iq result using the command workflow
  /// methods contained in the session instead of returning the response stanza
  /// itself. Defaults to `false`.
  static async.FutureOr<IQ> sendCommand<T>(
    JabberID jid,
    String node, {
    JabberID? iqFrom,
    String? sessionID,

    /// Must be in XMLBase or XML element type.
    List<Stanza>? payloads,
    String action = 'execute',
    async.FutureOr<T> Function(IQ result)? callback,
    async.FutureOr<void> Function(ErrorStanza error)? failureCallback,
    async.FutureOr<void> Function()? timeoutCallback,
    int timeout = 10,
  }) {
    final iq = IQ(generateID: true)
      ..type = iqTypeSet
      ..to = jid;

    if (iqFrom != null) iq.from = iqFrom;

    final command =
        Command(node, action: action, sessionID: sessionID, payloads: payloads);

    iq.payload = command;

    return iq.send(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Initiate executing a command provided by a remote agent.
  static async.FutureOr<IQ> startCommand(
    JabberID jid,
    String node,
    Map<String, dynamic> session, {
    JabberID? from,
  }) {
    session['jid'] = jid;
    session['node'] = node;
    session['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    if (!session.containsKey('payload')) {
      session['payload'] = null;
    }
    final iq = IQ(generateID: true)
      ..to = jid
      ..from = from
      ..type = iqTypeSet;
    if (from != null) session['from'] = from;
    bool includePayloads = false;
    late final List<Stanza> payloads;

    if ((session['payload'] as List<String>?)?.isNotEmpty ?? false) {
      includePayloads = true;
      if (includePayloads) payloads = <Stanza>[];
      for (final payload in session['payload'] as List<String>) {
        /// Parse an element from the saved payload in the session.
        final elementFromString = xml.XmlDocument.parse(payload).rootElement;

        payloads.add(
          Stanza.payloadFromXML(
            WhixpUtils.generateNamespacedElement(elementFromString),
            elementFromString,
          ),
        );
      }
    }

    final command = Command(
      node,
      action: 'execute',
      payloads: includePayloads ? payloads : null,
    );

    final sessionID = 'client:pending_${iq.id}';
    session['id'] = sessionID;
    _sessions[sessionID] = session;

    iq.payload = command;

    return iq.send();
  }
}
