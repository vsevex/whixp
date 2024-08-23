import 'dart:async';
import 'dart:collection';

import 'package:whixp/src/database/controller.dart';
import 'package:whixp/src/exception.dart';
import 'package:whixp/src/session.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/stanza/node.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

part 'stanza/_answer.dart';
part 'stanza/_enabled.dart';
part 'stanza/_failed.dart';
part 'stanza/_request.dart';
part 'stanza/_resumed.dart';

const _namespace = 'urn:xmpp:sm:3';
const _answer = 'sm:answer';
const _enable = 'sm:enable';
const _enabled = 'sm:enabled';
const _failed = 'sm:failed';
const _request = 'sm:request';
const _resume = 'sm:resume';
const _resumed = 'sm:resumed';

class StreamManagement {
  StreamManagement();

  xml.XmlElement toXML() => WhixpUtils.xmlElement('sm', namespace: _namespace);

  static Future<void> saveSMStateToLocal(String jid, SMState state) async {
    return HiveController.writeToSMBox(jid, state.toJson());
  }

  static Future<SMState?> getSMStateFromLocal(String? jid) async {
    if (jid?.isEmpty ?? true) return null;
    return await HiveController.readFromSMBox(jid!);
  }

  static Future<void>? saveUnackedToLocal(int sequence, Stanza stanza) =>
      HiveController.writeUnackeds(sequence, stanza);

  static Map<dynamic, String>? get unackeds => HiveController.unackeds;

  static String? popFromUnackeds() => HiveController.popUnacked();

  static Packet parse(xml.XmlElement node) {
    switch (node.localName) {
      case 'enabled':
        return SMEnabled.fromXML(node);
      case 'resumed':
        return SMResumed.fromXML(node);
      case 'r':
        return const SMRequest();
      case 'a':
        return SMAnswer.fromXML(node);
      case 'failed':
        return SMFailed.fromXML(node);
      default:
        throw WhixpInternalException.unexpectedPacket(
          _namespace,
          node.localName,
        );
    }
  }
}
