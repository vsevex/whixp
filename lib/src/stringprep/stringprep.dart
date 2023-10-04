import 'package:echox/src/stringprep/profiles.dart';
import 'package:echox/src/stringprep/tables.dart';

import 'package:memoize/memoize.dart';

typedef STRPREPFUNC = String Function(String str);

class StringPreparation {
  static List<dynamic>? _findRule(List<List<dynamic>> table, String character) {
    final code = character.codeUnitAt(0);
    var lo = 0;
    var hi = table.length;

    while (lo < hi) {
      final m = ((lo + hi) / 2).floor();
      final rule = table[m];
      if (code < (rule[0] as int)) {
        hi = m;
      } else if (code > (rule[1] as int)) {
        lo = m + 1;
      } else {
        return rule;
      }
    }

    return null;
  }

  /// Are any characters in the string subject to a rule in the table?
  static bool _someRule(List<List<dynamic>> table, String string) {
    return string.split('').any((character) {
      return _findRule(table, character) != null;
    });
  }

  static String _substituteString(List<List<dynamic>> table, String string) {
    return string.split('').map((character) {
      final rule = _findRule(table, character);
      return rule != null && rule.length >= 2 ? rule[2] : character;
    }).join();
  }

  /// operation
  /// ---------
  /// 0 - op code
  /// 1 - target table or null
  /// 2 and on - additional arguments
  static String _applyOperation(List<String?> operation, String str) {
    List<List<dynamic>>? table;

    if (operation.length >= 2 && operation[1] != null) {
      table = tables[operation[1]];
    }

    switch (operation[0]) {
      case 'map':
        return _substituteString(table!, str);
      case 'prohibit':
        if (_someRule(table!, str)) {
          throw Exception('stringprep contains prohibited');
        }
        return str;
      case 'unassigned':
        if (_someRule(table!, str)) {
          throw Exception('stringprep contains unassigned');
        }
        return str;
      default:
        return str;
    }
  }

  static String stringprep(String profile, String string) {
    final prof = profiles[profile];
    return prof!.fold(string, (String str, List<String> operation) {
      return _applyOperation(operation, str);
    });
  }

  Map<String, STRPREPFUNC> preps = <String, STRPREPFUNC>{}..addEntries(
      profileNames.map(
        (profileName) =>
            MapEntry(profileName, (String str) => stringprep(profileName, str)),
      ),
    );

  static bool inTableb1(String code) {
    final b1Set = memo1((Set<int> set) {
      /// Add the range of values to the set.
      for (int i = 65024; i < 65040; i++) {
        set.add(i);
      }

      return set;
    });

    return b1Set(<int>{
      173,
      847,
      6150,
      6155,
      6156,
      6157,
      8203,
      8204,
      8205,
      8288,
      65279,
    }).contains(code.runes.first);
  }

  static bool inTablec8(String code) {
    final c8Set = memo1((Set<int> set) {
      /// Add the range of values to the set.
      for (int i = 8234; i < 8239; i++) {
        set.add(i);
      }

      /// Add the second range of values to the set.
      for (int i = 8298; i < 8304; i++) {
        set.add(i);
      }

      return set;
    });

    return c8Set({832, 833, 8206, 8207}).contains(code.runes.first);
  }

  static bool inTablec12(String code) {
    return code.runes.isNotEmpty &&
        String.fromCharCode(code.runes.first).trim().isEmpty;
  }

  static bool _checkBidiCategory(String code) {
    const String rtlChars = r'\u0591-\u07FF\uFB1D-\uFDFD\uFE70-\uFEFC';
    return RegExp('[' '$rtlChars' ']').hasMatch(code);
  }

  static bool inTabled1(String code) {
    final check = memo1((String a) => _checkBidiCategory(code));
    final bidiCategory = check(code) ? 'R' : 'L';
    return bidiCategory == 'R' || bidiCategory == 'AL';
  }

  static bool inTabled2(String code) {
    final check = memo1((String a) => _checkBidiCategory(code));
    return !check(code);
  }
}
