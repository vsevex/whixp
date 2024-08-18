import 'package:hive/hive.dart';

import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/session.dart';
import 'package:whixp/src/stanza/stanza.dart';

/// Manages interaction with a Hive storage box for storing key-value pairs.
class HiveController {
  /// Constructs a [HiveController].
  HiveController();

  /// The static storage box for key-value pairs.
  static Box<Map<dynamic, dynamic>>? _smBox;

  /// Static storage box for unacked stanza records.
  static Box<String>? _unackeds;

  /// Initializes the storage box.
  ///
  /// If [path] is provided, the storage box will be opened at the specified
  /// path.
  static Future<void> initialize([String? path]) async {
    if (_smBox != null) {
      Log.instance.warning(
        'Tried to reinitialize sm box, but it is already initialized',
      );
    }
    if (_unackeds != null) {
      Log.instance.warning(
        'Tried to reinitialize unacked stanzas box, but it is already initialized',
      );
    }
    _smBox = await Hive.openBox<Map<dynamic, dynamic>>('sm', path: path);
    _unackeds = await Hive.openBox<String>('unacked', path: path);
    return;
  }

  /// Writes a key-value pair to the storage box.
  ///
  /// [jid] is the key associated with the provided [state].
  static Future<void> writeToSMBox(String jid, Map<String, dynamic> state) =>
      _smBox!.put(jid, state);

  /// Writes a key-value pair to the storage box.
  ///
  /// [sequence] is the key associated with the provided unacked [stanza].
  static Future<void> writeUnackeds(int sequence, Stanza stanza) =>
      _unackeds!.put(sequence, stanza.toXMLString());

  /// All available key-value pairs for lcaolly saved unacked stanzas.
  static Map<dynamic, String> get unackeds => _unackeds!.toMap();

  /// Pops from the unacked stanzas list.
  static String? popUnacked() {
    final unacked = _unackeds?.getAt(0);
    _unackeds?.deleteAt(0);
    return unacked;
  }

  /// Reads a key-value pair from the storage box.
  ///
  /// [jid] is the key associated with the value to be read.
  /// Returns a [Future] that completes with the [SMState] associated with [jid],
  /// or `null` if [jid] does not exist in the storage box.
  static Future<SMState?> readFromSMBox(String jid) async {
    final data = _smBox?.get(jid);
    if (data == null) return null;
    return SMState.fromJson(Map<String, dynamic>.from(_smBox!.get(jid)!));
  }
}
