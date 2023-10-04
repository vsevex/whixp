import 'package:echox/echox.dart';
import 'package:echox/src/stringprep/stringprep.dart';

import 'package:unorm_dart/unorm_dart.dart' as unorm;

class StringPreparationProfiles {
  const StringPreparationProfiles();

  static String? b1Map(String char) =>
      StringPreparation.inTableb1(char) ? '' : null;

  static String? c12Map(String char) =>
      StringPreparation.inTablec12(char) ? '' : null;

  static String mapInput(
    String data, [
    List<String? Function(String)>? tables,
  ]) {
    final result = <String>[];

    if (tables == null) {
      return data;
    }

    for (int i = 0; i < data.length; i++) {
      final char = data[i];
      String? replacement;

      for (final mapping in tables) {
        replacement = mapping(char);
        if (replacement != null) {
          break;
        }
      }

      if (replacement != null) {
        replacement = char;
      }
      result.add(char);
    }

    return result.join();
  }

  static String normalize(String data, {bool nkfc = true}) {
    if (nkfc) {
      return unorm.nfkc(data);
    }
    return data;
  }

  static bool prohibitOutput(
    String data, [
    List<bool Function(String)>? tables,
  ]) {
    if (tables == null) {
      return false;
    }

    for (int i = 0; i < data.length; i++) {
      final char = data[i];

      for (final check in tables) {
        if (check(char)) {
          return false;
        }
      }
    }

    return true;
  }

  static bool checkBidi(String data) {
    if (data.isEmpty) {
      return false;
    }

    bool hasLcat = false;
    bool hasRandal = false;

    for (int i = 0; i < data.length; i++) {
      final char = data[i];

      if (StringPreparation.inTablec8(char)) {
        return false;
      }
      if (StringPreparation.inTabled1(char)) {
        hasRandal = true;
      } else if (StringPreparation.inTabled2(char)) {
        hasLcat = true;
      }
    }

    if (hasRandal && hasLcat) {
      return false;
    }

    final firstRandal = StringPreparation.inTabled1(data[0]);
    final lastRandal = StringPreparation.inTabled1(data[data.length - 1]);

    if (firstRandal && !(firstRandal && lastRandal)) {
      return false;
    }

    return true;
  }

  static String stringPreparationProfile({
    bool nkfc = true,
    bool bidi = true,
    List<String? Function(String)>? mappings,
    List<bool Function(String)>? prohibited,
    List<bool Function(String)>? unassigned,
  }) {
    String profile(dynamic data, {bool query = false}) {
      String text;
      try {
        text = Echotils.unicode(data);
      } catch (error) {
        throw ArgumentError('String preparation error occured');
      }

      String edited = mapInput(text, mappings);
      edited = normalize(edited, nkfc: nkfc);
      prohibitOutput(edited, prohibited);
      if (bidi) {
        checkBidi(edited);
      }
      if (query && unassigned != null) {
        throw Exception();
      }
    }

    return profile();
  }
}
