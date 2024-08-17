// part of 'command.dart';

// class _HiveDatabase {
//   factory _HiveDatabase() => _instance;

//   _HiveDatabase._();

//   late Box<Map<dynamic, dynamic>> box;

//   static final _HiveDatabase _instance = _HiveDatabase._();

//   Future<void> initialize(String name, [String? path]) async =>
//       box = await Hive.openBox<Map<dynamic, dynamic>>(name, path: path);

//   Map<dynamic, dynamic>? getSession(String sessionID) => box.get(sessionID);
// }
