// part of 'manager.dart';

// class _HiveDatabase {
//   factory _HiveDatabase() => _instance;

//   _HiveDatabase._();

//   late Box<Map<dynamic, dynamic>> box;

//   static final _HiveDatabase _instance = _HiveDatabase._();

//   Future<void> initialize(String name, [String? path]) async =>
//       box = await Hive.openBox<Map<dynamic, dynamic>>(name, path: path);

//   Map<dynamic, dynamic>? getState(String owner, String jid) {
//     final data = getJID(owner);

//     return data == null ? null : data[jid] as Map<dynamic, dynamic>;
//   }

//   Map<dynamic, dynamic>? getJID(String owner) => box.get(owner);

//   Stream<BoxEvent> listenable() => box.watch();

//   Future<void> updateData(
//     String owner,
//     String jid,
//     Map<dynamic, dynamic> data,
//   ) {
//     final existingData = getJID(owner);
//     if (existingData != null) {
//       existingData.addAll({jid: data});
//     }
//     return box.put(owner, existingData ?? {jid: data});
//   }
// }
