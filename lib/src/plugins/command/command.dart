import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:hive/hive.dart';

import 'package:whixp/src/exception.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/plugins/plugins.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/stream/matcher/matcher.dart';
import 'package:whixp/src/utils/utils.dart';
import 'package:whixp/src/whixp.dart';

import 'package:xml/xml.dart' as xml;

part '_database.dart';
part 'stanza.dart';

const _commandTable = 'commands';

typedef _Handler = FutureOr<dynamic> Function(
  IQ iq,
  Map<String, dynamic>? session, [
  dynamic results,
]);

///  XMPP's Adhoc Commands provides a generic workflow mechanism for interacting
/// with applications.
///
/// see <http://xmpp.org/extensions/xep-0050.html>
class AdHocCommands extends PluginBase {
  /// Events:
  ///
  /// * `execute`: received a command with action "execute"
  /// * `next`: received a command with action "next"
  /// * `complete`: received a command with action "complete"
  /// * `cancel`: received a command with action "cancel"
  AdHocCommands()
      : super(
          'commands',
          description: 'XEP-0050: Ad-Hoc Commands',
          dependencies: <String>{'disco', 'forms'},
        );

  late final Map<String, Map<String, dynamic>> _sessions;
  late final Map<Tuple2<String, String?>, Tuple2<String, _Handler?>> _commands;
  final _commandNamespace = Command().namespace;

  @override
  void pluginInitialize() {
    _setBackend();

    _sessions = <String, Map<String, dynamic>>{};
    _commands = <Tuple2<String, String?>, Tuple2<String, _Handler?>>{};

    base.transport
      ..registerHandler(
        CallbackHandler(
          'Ad-Hoc Execute',
          (stanza) => _handleCommand(stanza as IQ),
          matcher: StanzaPathMatcher('iq@type=set/command'),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'Ad-Hoc Result',
          (stanza) => _handleCommandResult(stanza as IQ),
          matcher: StanzaPathMatcher('iq@type=result/command'),
        ),
      )
      ..addEventHandler<IQ>('command', _handleAllCommands);
  }

  Future<void> _setBackend() async {
    await _HiveDatabase().initialize(
      _commandTable,
      base.provideHivePath ? base.hivePathName : null,
    );
  }

  /// Makes a command available to external entities.
  ///
  /// Access control may be implemented in the provided handler.
  void addCommand({
    JabberID? jid,
    String? node,
    String name = '',
    _Handler? handler,
  }) {
    jid ??= base.transport.boundJID;
    final itemJid = jid.full;

    final disco = base.getPluginInstance<ServiceDiscovery>('disco');
    if (disco != null) {
      disco
        ..addIdentity(
          category: 'automation',
          type: 'command-list',
          name: 'Ad-Hoc commands',
          node: _commandNamespace,
          jid: jid,
        )
        ..addItem(
          jid: itemJid,
          name: name,
          node: _commandNamespace,
          subnode: node,
          itemJid: jid,
        )
        ..addIdentity(
          category: 'automation',
          type: 'command-node',
          name: name,
          node: node,
          jid: jid,
        )
        ..addFeature(_commandNamespace, jid: jid);
    }

    _commands[Tuple2(itemJid, node)] = Tuple2(name, handler);
  }

  /// Emits command events based on the command action.
  void _handleCommand(IQ iq) => base.transport
    ..emit<IQ>('command', data: iq)
    ..emit(
      'command${((iq['command'] as Command)['action'] as String).capitalize()}',
      data: iq,
    );

  Future<void> _handleAllCommands(IQ? iq) async {
    if (iq == null) return;
    final command = iq['command'] as Command;
    final action = command['action'] as String;
    final sessionID = command['sessionid'] as String;
    final session = _HiveDatabase().getSession(sessionID);

    if (session == null) {
      return _handleCommandStart(iq);
    }

    if ({'next', 'execute'}.contains(action)) {
      return _handleCommandNext(iq);
    }
    if (action == 'prev') {
      return _handleCommandPrev(iq);
    }
    if (action == 'complete') {
      return _handleCommandComplete(iq);
    }
    if (action == 'cancel') {
      return _handleCommandCancel(iq);
    }
  }

  /// Generates a command reply stanza based on the provided session data.
  void _processCommandResponse(IQ iq, Map<String, dynamic> session) {
    final sessionID = session['id'] as String;

    final payloads = session['payload'] as List<XMLBase>? ?? <XMLBase>[];
    final interfaces = session['interfaces'] as Set<String>;
    final payloadTypes = session['payloadTypes'] as Set<Type>;

    if (payloads.isNotEmpty) {
      for (final payload in payloads) {
        interfaces.add(payload.pluginAttribute);
        payloadTypes.add(payload.runtimeType);
      }
    }

    session['interfaces'] = interfaces;
    session['payloadTypes'] = payloadTypes;

    _sessions[sessionID] = session;

    for (final item in payloads) {
      registerStanzaPlugin(Command(), item, iterable: true);
    }

    final reply = iq.replyIQ();
    reply.transport = base.transport;
    final command = reply['command'] as Command;
    command['node'] = session['node'];
    command['sessionid'] = session['id'];

    if (command['node'] == null) {
      command['actions'] = [];
      command['status'] = 'completed';
    } else if (session['hasNext'] as bool) {
      final actions = <String>['next'];
      if (session['allowComplete'] as bool) {
        actions.add('complete');
      } else if (session['allowPrev'] as bool) {
        actions.add('prev');
      }
      command['actions'] = actions;
      command['status'] = 'executing';
    } else {
      command['actions'] = ['complete'];
      command['status'] = 'executing';
    }
    command['notes'] = session['notes'];

    for (final item in payloads) {
      command.add(item);
    }

    reply.sendIQ();
  }

  /// Processes an initial request to execute a command.
  Future<void> _handleCommandStart(IQ iq) async {
    final sessionID = WhixpUtils.getUniqueId();
    final node = (iq['command'] as Command)['node'] as String;
    final key = Tuple2<String, String?>(iq.to != null ? iq.to!.full : '', node);
    final command = _commands[key];
    if (command == null || command.value2 == null) {
      Log.instance.info('Command not found: $key, $command');
      throw StanzaException(
        'Command start exception',
        condition: 'item-not-found',
      );
    }

    final payload = <XMLBase>[];
    for (final stanza
        in (iq['command'] as Command)['substanzas'] as List<XMLBase>) {
      payload.add(stanza);
    }

    final interfaces =
        Set<String>.from(payload.map((item) => item.pluginAttribute));
    final payloadTypes =
        Set<Type>.from(payload.map((item) => item.runtimeType));

    final initialSession = <String, dynamic>{
      'id': sessionID,
      'from': iq.from,
      'to': iq.to,
      'node': node,
      'payload': payload,
      'interfaces': interfaces,
      'payloadTypes': payloadTypes,
      'notes': null,
      'hasNext': false,
      'allowComplete': false,
      'allowPrev': false,
      'past': [],
      'next': null,
      'prev': null,
      'cancel': null,
    };

    final handler = command.value2!;
    final session =
        await handler.call(iq, initialSession) as Map<String, dynamic>;
    _processCommandResponse(iq, session);
  }

  /// Processes the results of a command request.
  void _handleCommandResult(IQ iq) {
    String sessionID = 'client:${(iq['command'] as Command)['sessionid']}';
    late String pendingID;
    bool pending = false;

    if (!_sessions.containsKey(sessionID) || _sessions[sessionID] == null) {
      pending = true;
      if ((iq['id'] as String).isEmpty) {
        pendingID = _sessions.entries.last.key;
      } else {
        pendingID = 'client:pending_${iq['id']}';
      }
      if (!_sessions.containsKey(pendingID)) {
        return;
      }

      sessionID = pendingID;
    }
    final command = iq['command'] as Command;

    final session = _sessions[sessionID];
    sessionID = 'client:${command['sessionid']}';
    session!['id'] = command['sessionid'];

    _sessions[sessionID] = session;

    if (pending) {
      _sessions.remove(pendingID);
    }

    String handlerType = 'next';
    if (iq['type'] == 'error') {
      handlerType = 'error';
    }
    final handler = session[handlerType] as _Handler?;
    if (handler != null) {
      handler.call(iq, session);
    } else if (iq['type'] == 'error') {
      terminateCommand(session);
    }

    if (command['status'] == 'completed') {
      terminateCommand(session);
    }
  }

  /// Process a request for the next step in the workflow for a command with
  /// multiple steps.
  Future<void> _handleCommandNext(IQ iq) async {
    final command = iq['command'] as Command;
    final sessionID = command['sessionid'] as String;
    final session = _sessions[sessionID];

    if (session != null) {
      final handler = session['next'] as _Handler;
      final interfaces = session['interfaces'] as Set<String>;
      final results = <XMLBase>[];

      for (final stanza in command['substanzas'] as List<XMLBase>) {
        if (interfaces.contains(stanza.pluginAttribute)) {
          results.add(stanza);
        }
      }

      final newSession =
          await handler.call(iq, session, results) as Map<String, dynamic>;

      _processCommandResponse(iq, newSession);
    } else {
      throw StanzaException(
        'Command start exception',
        condition: 'item-not-found',
      );
    }
  }

  /// Processes a request for the previous step in the workflow for a command
  /// with multiople steps.
  Future<void> _handleCommandPrev(IQ iq) async {
    final command = iq['command'] as Command;
    final sessionID = command['sessionid'] as String;
    Map<String, dynamic>? session = _sessions[sessionID];

    if (session != null) {
      final handler = session['prev'] as _Handler?;
      final interfaces = session['interfaces'] as Set<String>;
      final results = <XMLBase>[];
      for (final stanza in command['substanzas'] as List<XMLBase>) {
        if (interfaces.contains(stanza.pluginAttribute)) {
          results.add(stanza);
        }
      }

      session =
          await handler?.call(iq, session, results) as Map<String, dynamic>;

      _processCommandResponse(iq, session);
    } else {
      throw StanzaException(
        'Command start exception',
        condition: 'item-not-found',
      );
    }
  }

  /// Processes a request to finish the execution of command and terminate the
  /// workflow.
  Future<void> _handleCommandComplete(IQ iq) async {
    final command = iq['command'] as Command;
    final node = command['node'] as String;
    final sessionID = command['sessionid'] as String;
    final session = _sessions[sessionID];

    if (session != null) {
      final handler = session['prev'] as _Handler?;
      final interfaces = session['interfaces'] as Set<String>;
      final results = <XMLBase>[];
      for (final stanza in command['substanzas'] as List<XMLBase>) {
        if (interfaces.contains(stanza.pluginAttribute)) {
          results.add(stanza);
        }
      }

      if (handler != null) {
        await handler(iq, session, results);
      }

      _sessions.remove(sessionID);

      final payloads = session['payload'] as List<XMLBase>? ?? <XMLBase>[];

      for (final payload in payloads) {
        registerStanzaPlugin(Command(), payload);
      }

      final reply = iq.replyIQ()
        ..transport = base.transport
        ..enable('command');

      final replyCommand = reply['command'] as Command;
      replyCommand['node'] = node;
      replyCommand['sessionid'] = sessionID;
      replyCommand['actions'] = [];
      replyCommand['status'] = 'completed';
      replyCommand['notes'] = session['notes'];

      for (final payload in payloads) {
        replyCommand.add(payload);
      }

      reply.sendIQ();
    } else {
      throw StanzaException(
        'Command start exception',
        condition: 'item-not-found',
      );
    }
  }

  /// Processes a request to cancel a command's execution.
  Future<void> _handleCommandCancel(IQ iq) async {
    final command = iq['command'] as Command;
    final node = command['node'] as String;
    final sessionID = command['sessiondid'];
    final session = _sessions[sessionID];

    if (session != null) {
      final handler = session['cancel'] as _Handler?;
      if (handler != null) {
        await handler.call(iq, session);
      }
      _sessions.remove(sessionID);

      final reply = iq.replyIQ()
        ..transport = base.transport
        ..enable('command');

      final replyCommand = reply['command'] as Command;
      replyCommand['node'] = node;
      replyCommand['sessionid'] = sessionID;
      replyCommand['status'] = 'canceled';
      replyCommand['notes'] = session['notes'];

      reply.sendIQ();
    } else {
      throw StanzaException(
        'Command start exception',
        condition: 'item-not-found',
      );
    }
  }

  /// Creates and sends a command stanza.
  ///
  /// If [flow] is true, the process the Iq result using the command workflow
  /// methods contained in the session instead of returning the response stanza
  /// itself. Defaults to `false`.
  FutureOr<IQ> sendCommand(
    JabberID jid,
    String node, {
    JabberID? iqFrom,
    String? sessionID,

    /// Must be in XMLBase or XMl element type.
    List<dynamic>? payloads,
    String action = 'execute',
  }) {
    final iq = base.makeIQSet()..enable('command');
    iq['to'] = jid;
    if (iqFrom != null) {
      iq['from'] = iqFrom;
    }
    final command = iq['command'] as Command;
    command['node'] = node;
    command['action'] = action;
    if (sessionID != null) {
      command['sessionid'] = sessionID;
    }
    if (payloads != null) {
      for (final payload in payloads) {
        command.add(payload);
      }
    }

    return iq.sendIQ();
  }

  /// Initiate executing a command provided by a remote agent.
  FutureOr<IQ> startCommand(
    JabberID jid,
    String node,
    Map<String, dynamic> session, {
    JabberID? iqFrom,
  }) {
    session['jid'] = jid;
    session['node'] = node;
    session['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    if (!session.containsKey('payload')) {
      session['payload'] = null;
    }
    final iq = base.makeIQSet(iqTo: jid, iqFrom: iqFrom);
    session['from'] = iqFrom;
    (iq['command'] as Command)['node'] = node;
    (iq['command'] as Command)['action'] = 'execute';
    if (session['payload'] != null) {
      /// Although it accepts dynamic, the list must contain either XMLBase or
      /// XML element (from xml package).
      final payload = session['payload'] as List<dynamic>;
      for (final stanza in payload) {
        (iq['command'] as Command).add(stanza);
      }
    }
    final sessionID = 'client:pending_${iq['id']}';
    session['id'] = sessionID;
    _sessions[sessionID] = session;

    return iq.sendIQ();
  }

  FutureOr<IQ> continueCommand(
    Map<String, dynamic> session, {
    String direction = 'next',
  }) {
    final sessionID = 'client:${session['id']}';
    _sessions[sessionID] = session;

    return sendCommand(
      session['jid'] as JabberID,
      session['node'] as String,
      iqFrom: session['from'] as JabberID?,
      sessionID: session['id'] as String,
      action: direction,
      payloads: (session['payload'] is List)
          ? session['payload'] as List<XMLBase>?
          : <XMLBase>[session['payload'] as XMLBase],
    );
  }

  /// Deletes a command's session after a command has completed or an error has
  /// occured.
  void terminateCommand(Map<String, dynamic> session) {
    final sessionID = 'client:${session['id']}';
    _sessions.remove(sessionID);
  }

  @override
  void sessionBind(String? jid) {
    final disco = base.getPluginInstance<ServiceDiscovery>('disco');
    if (disco != null) {
      disco
        ..addFeature(_commandNamespace)
        ..setItems(items: <SingleDiscoveryItem>{});
    }
  }

  @override
  void pluginEnd() {
    base.transport
      ..removeEventHandler('command', handler: _handleAllCommands)
      ..removeHandler('Ad-Hoc Execute')
      ..removeHandler('Ad-Hoc Result');

    final disco = base.getPluginInstance<ServiceDiscovery>(
      'disco',
      enableIfRegistered: false,
    );
    if (disco != null) {
      disco
        ..removeFeature(_commandNamespace)
        ..setItems(items: <SingleDiscoveryItem>{});
    }
  }
}
