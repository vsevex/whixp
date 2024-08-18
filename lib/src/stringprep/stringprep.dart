import 'package:memoize/memoize.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

part 'profiles.dart';
part 'tables.dart';

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
}

class StandaloneStringPreparation {
  const StandaloneStringPreparation();
  static const String _rtlChars = r'\u0591-\u07FF\uFB1D-\uFDFD\uFE70-\uFEFC';
  static const String _ltrChars =
      r'A-Za-z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u02B8\u0300-\u0590'
      r'\u0800-\u1FFF\u2C00-\uFB1C\uFDFE-\uFE6F\uFEFD-\uFFFF';

  static const _zsCodePoints = [
    0x0020, // Basic Latin - Space
    0x00A0, // Latin-1 Supplement - No-Break Space
    0x2000, // General Punctuation - En Quad
    0x2001, // General Punctuation - Em Quad
    0x2002, // General Punctuation - En Space
    0x2003, // General Punctuation - Em Space
    0x2004, // General Punctuation - Three-Per-Em Space
    0x2005, // General Punctuation - Four-Per-Em Space
    0x2006, // General Punctuation - Six-Per-Em Space
    0x2007, // General Punctuation - Figure Space
    0x2008, // General Punctuation - Punctuation Space
    0x2009, // General Punctuation - Thin Space
    0x200A, // General Punctuation - Hair Space
    0x200B, // General Punctuation - Zero Width Space
    0x205F, // Mathematical Operators - Medium Mathematical Space
  ];

  static Set<int> get _generateb1Set {
    final set = <int>{
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
    };

    /// Add the range of values to the set
    for (int i = 65024; i < 65040; i++) {
      set.add(i);
    }

    return set;
  }

  static String mapTableb3(String code) {
    final result = _b3Exceptions[code.runes.first];
    if (result != null) {
      return result;
    }
    return code.toLowerCase();
  }

  static String mapTableb2(String code) {
    final al = mapTableb3(code);
    final b = unorm.nfkc(al);
    final bl = String.fromCharCodes(
      b.runes
          .map((char) => mapTableb3(String.fromCharCode(char)).codeUnits)
          .expand((x) => x),
    );
    final c = unorm.nfkc(bl);
    if (b != c) {
      return c;
    } else {
      return al;
    }
  }

  static void _addCodePointRange(List<int> list, int start, int end) {
    for (int codePoint = start; codePoint <= end; codePoint++) {
      list.add(codePoint);
    }
  }

  static List<int> get _generateListOfControlChars {
    final controlCharacterRange = <int>[];

    for (int codePoint = 0x0000; codePoint <= 0x001F; codePoint++) {
      controlCharacterRange.add(codePoint);
    }

    controlCharacterRange.add(0x007F);

    for (int codePoint = 0x0080; codePoint <= 0x009F; codePoint++) {
      controlCharacterRange.add(codePoint);
    }

    return controlCharacterRange;
  }

  static List<int> get _generateListOfCoChars {
    final coChars = <int>[];

    _addCodePointRange(coChars, 0xE000, 0xF8FF);
    _addCodePointRange(coChars, 0xF0000, 0xFFFFD);
    _addCodePointRange(coChars, 0x100000, 0x10FFFD);

    return coChars;
  }

  static List<int> get _generateListOfSurrogateChars {
    final surrogateChars = <int>[];

    _addCodePointRange(surrogateChars, 0xD800, 0xDBFF);
    _addCodePointRange(surrogateChars, 0xDC00, 0xDFFF);

    return surrogateChars;
  }

  static bool inTableb1(String code) {
    final b1Set = memo0(() => _generateb1Set).call();

    return b1Set.contains(code.runes.first);
  }

  static bool inTablec11(String code) => code == ' ';

  static bool inTablec12(String code) {
    return memo1<int, bool>(
          (int codepoint) => _zsCodePoints.contains(codepoint),
        ).call(code.runes.first) &&
        code != ' ';
  }

  static bool inTablec22(String code) {
    late final controlCharactersRange =
        memo0<List<int>>(() => _generateListOfControlChars).call();

    late final c22Set = memo0<Set<int>>(
      () => <int>{
        1757,
        1807,
        6158,
        8204,
        8205,
        8232,
        8233,
        65279,
        ...List<int>.generate(4, (index) => 8288 + index),
        ...List<int>.generate(6, (index) => 8298 + index),
        ...List<int>.generate(4, (index) => 65529 + index),
        ...List<int>.generate(8, (index) => 119155 + index),
      },
    ).call();

    final c22 = memo1<int, bool>((int codepoint) {
      if (codepoint < 128) {
        return false;
      }

      if (controlCharactersRange.contains(codepoint)) return true;

      return c22Set.contains(codepoint);
    });

    return c22(code.runes.first);
  }

  static bool inTablec3(String code) {
    final coChars = _generateListOfCoChars;
    final c3 = memo1<int, bool>((int codepoint) => coChars.contains(codepoint));

    return c3(code.runes.first);
  }

  static bool inTablec4(String code) {
    final inc4 = memo1<int, bool>((int codepoint) {
      if (codepoint < 0xFDD0) return false;
      if (codepoint < 0xFDF0) return true;
      return (codepoint & 0xFFFF) == 0xFFFE || (codepoint & 0xFFFF) == 0xFFFF;
    });

    return inc4(code.runes.first);
  }

  static bool inTablec5(String code) {
    final surrogateCodePoints = _generateListOfSurrogateChars;
    final c5 = memo1<int, bool>(
      (int codepoint) => surrogateCodePoints.contains(codepoint),
    );

    return c5(code.runes.first);
  }

  static bool inTablec6(String code) {
    final c6Set = memo0(
      () => Set<int>.from(List<int>.generate(5, (index) => 65529 + index)),
    ).call();
    final c6 = memo1<int, bool>((int codepoint) => c6Set.contains(codepoint));
    return c6(code.runes.first);
  }

  static bool inTablec7(String code) {
    final c7Set = memo0(
      () => Set<int>.from(List<int>.generate(12, (index) => 12272 + index)),
    ).call();
    final c7 = memo1<int, bool>((int codepoint) => c7Set.contains(codepoint));
    return c7(code.runes.first);
  }

  static bool inTablec8(String code) {
    final c8Set = memo0(() {
      final set = <int>{832, 833, 8206, 8207};

      /// Add the range of values to the set.
      for (int i = 8234; i < 8239; i++) {
        set.add(i);
      }

      /// Add the second range of values to the set.
      for (int i = 8298; i < 8304; i++) {
        set.add(i);
      }

      return set;
    }).call();

    return c8Set.contains(code.runes.first);
  }

  static bool inTablec9(String code) {
    final c9Set = memo0(
      () => <int>{917505, ...List<int>.generate(96, (index) => 917536 + index)},
    ).call();

    return c9Set.contains(code.runes.first);
  }

  static bool _hasAnyRtl(String code) =>
      RegExp('[' '$_rtlChars' ']').hasMatch(code);

  static bool _hasAnyLtr(String code) =>
      RegExp('[' '$_ltrChars' ']').hasMatch(code);

  static bool inTabled1(String code) => _hasAnyRtl(code);

  static bool inTabled2(String code) => _hasAnyLtr(code);

  static String normalize(String data, {bool nkfc = true}) {
    if (nkfc) {
      return unorm.nfkc(data);
    }
    return data;
  }
}

final _b3Exceptions = <int, String>{
  0xb5: '\u03bc',
  0xdf: 'ss',
  0x130: 'i\u0307',
  0x149: '\u02bcn',
  0x17f: 's',
  0x1f0: 'j\u030c',
  0x345: '\u03b9',
  0x37a: ' \u03b9',
  0x390: '\u03b9\u0308\u0301',
  0x3b0: '\u03c5\u0308\u0301',
  0x3c2: '\u03c3',
  0x3d0: '\u03b2',
  0x3d1: '\u03b8',
  0x3d2: '\u03c5',
  0x3d3: '\u03cd',
  0x3d4: '\u03cb',
  0x3d5: '\u03c6',
  0x3d6: '\u03c0',
  0x3f0: '\u03ba',
  0x3f1: '\u03c1',
  0x3f2: '\u03c3',
  0x3f5: '\u03b5',
  0x587: '\u0565\u0582',
  0x1e96: 'h\u0331',
  0x1e97: 't\u0308',
  0x1e98: 'w\u030a',
  0x1e99: 'y\u030a',
  0x1e9a: 'a\u02be',
  0x1e9b: '\u1e61',
  0x1f50: '\u03c5\u0313',
  0x1f52: '\u03c5\u0313\u0300',
  0x1f54: '\u03c5\u0313\u0301',
  0x1f56: '\u03c5\u0313\u0342',
  0x1f80: '\u1f00\u03b9',
  0x1f81: '\u1f01\u03b9',
  0x1f82: '\u1f02\u03b9',
  0x1f83: '\u1f03\u03b9',
  0x1f84: '\u1f04\u03b9',
  0x1f85: '\u1f05\u03b9',
  0x1f86: '\u1f06\u03b9',
  0x1f87: '\u1f07\u03b9',
  0x1f88: '\u1f00\u03b9',
  0x1f89: '\u1f01\u03b9',
  0x1f8a: '\u1f02\u03b9',
  0x1f8b: '\u1f03\u03b9',
  0x1f8c: '\u1f04\u03b9',
  0x1f8d: '\u1f05\u03b9',
  0x1f8e: '\u1f06\u03b9',
  0x1f8f: '\u1f07\u03b9',
  0x1f90: '\u1f20\u03b9',
  0x1f91: '\u1f21\u03b9',
  0x1f92: '\u1f22\u03b9',
  0x1f93: '\u1f23\u03b9',
  0x1f94: '\u1f24\u03b9',
  0x1f95: '\u1f25\u03b9',
  0x1f96: '\u1f26\u03b9',
  0x1f97: '\u1f27\u03b9',
  0x1f98: '\u1f20\u03b9',
  0x1f99: '\u1f21\u03b9',
  0x1f9a: '\u1f22\u03b9',
  0x1f9b: '\u1f23\u03b9',
  0x1f9c: '\u1f24\u03b9',
  0x1f9d: '\u1f25\u03b9',
  0x1f9e: '\u1f26\u03b9',
  0x1f9f: '\u1f27\u03b9',
  0x1fa0: '\u1f60\u03b9',
  0x1fa1: '\u1f61\u03b9',
  0x1fa2: '\u1f62\u03b9',
  0x1fa3: '\u1f63\u03b9',
  0x1fa4: '\u1f64\u03b9',
  0x1fa5: '\u1f65\u03b9',
  0x1fa6: '\u1f66\u03b9',
  0x1fa7: '\u1f67\u03b9',
  0x1fa8: '\u1f60\u03b9',
  0x1fa9: '\u1f61\u03b9',
  0x1faa: '\u1f62\u03b9',
  0x1fab: '\u1f63\u03b9',
  0x1fac: '\u1f64\u03b9',
  0x1fad: '\u1f65\u03b9',
  0x1fae: '\u1f66\u03b9',
  0x1faf: '\u1f67\u03b9',
  0x1fb2: '\u1f70\u03b9',
  0x1fb3: '\u03b1\u03b9',
  0x1fb4: '\u03ac\u03b9',
  0x1fb6: '\u03b1\u0342',
  0x1fb7: '\u03b1\u0342\u03b9',
  0x1fbc: '\u03b1\u03b9',
  0x1fbe: '\u03b9',
  0x1fc2: '\u1f74\u03b9',
  0x1fc3: '\u03b7\u03b9',
  0x1fc4: '\u03ae\u03b9',
  0x1fc6: '\u03b7\u0342',
  0x1fc7: '\u03b7\u0342\u03b9',
  0x1fcc: '\u03b7\u03b9',
  0x1fd2: '\u03b9\u0308\u0300',
  0x1fd3: '\u03b9\u0308\u0301',
  0x1fd6: '\u03b9\u0342',
  0x1fd7: '\u03b9\u0308\u0342',
  0x1fe2: '\u03c5\u0308\u0300',
  0x1fe3: '\u03c5\u0308\u0301',
  0x1fe4: '\u03c1\u0313',
  0x1fe6: '\u03c5\u0342',
  0x1fe7: '\u03c5\u0308\u0342',
  0x1ff2: '\u1f7c\u03b9',
  0x1ff3: '\u03c9\u03b9',
  0x1ff4: '\u03ce\u03b9',
  0x1ff6: '\u03c9\u0342',
  0x1ff7: '\u03c9\u0342\u03b9',
  0x1ffc: '\u03c9\u03b9',
  0x20a8: 'rs',
  0x2102: 'c',
  0x2103: '\xb0c',
  0x2107: '\u025b',
  0x2109: '\xb0f',
  0x210b: 'h',
  0x210c: 'h',
  0x210d: 'h',
  0x2110: 'i',
  0x2111: 'i',
  0x2112: 'l',
  0x2115: 'n',
  0x2116: 'no',
  0x2119: 'p',
  0x211a: 'q',
  0x211b: 'r',
  0x211c: 'r',
  0x211d: 'r',
  0x2120: 'sm',
  0x2121: 'tel',
  0x2122: 'tm',
  0x2124: 'z',
  0x2128: 'z',
  0x212c: 'b',
  0x212d: 'c',
  0x2130: 'e',
  0x2131: 'f',
  0x2133: 'm',
  0x213e: '\u03b3',
  0x213f: '\u03c0',
  0x2145: 'd',
  0x3371: 'hpa',
  0x3373: 'au',
  0x3375: 'ov',
  0x3380: 'pa',
  0x3381: 'na',
  0x3382: '\u03bca',
  0x3383: 'ma',
  0x3384: 'ka',
  0x3385: 'kb',
  0x3386: 'mb',
  0x3387: 'gb',
  0x338a: 'pf',
  0x338b: 'nf',
  0x338c: '\u03bcf',
  0x3390: 'hz',
  0x3391: 'khz',
  0x3392: 'mhz',
  0x3393: 'ghz',
  0x3394: 'thz',
  0x33a9: 'pa',
  0x33aa: 'kpa',
  0x33ab: 'mpa',
  0x33ac: 'gpa',
  0x33b4: 'pv',
  0x33b5: 'nv',
  0x33b6: '\u03bcv',
  0x33b7: 'mv',
  0x33b8: 'kv',
  0x33b9: 'mv',
  0x33ba: 'pw',
  0x33bb: 'nw',
  0x33bc: '\u03bcw',
  0x33bd: 'mw',
  0x33be: 'kw',
  0x33bf: 'mw',
  0x33c0: 'k\u03c9',
  0x33c1: 'm\u03c9',
  0x33c3: 'bq',
  0x33c6: 'c\u2215kg',
  0x33c7: 'co.',
  0x33c8: 'db',
  0x33c9: 'gy',
  0x33cb: 'hp',
  0x33cd: 'kk',
  0x33ce: 'km',
  0x33d7: 'ph',
  0x33d9: 'ppm',
  0x33da: 'pr',
  0x33dc: 'sv',
  0x33dd: 'wb',
  0xfb00: 'ff',
  0xfb01: 'fi',
  0xfb02: 'fl',
  0xfb03: 'ffi',
  0xfb04: 'ffl',
  0xfb05: 'st',
  0xfb06: 'st',
  0xfb13: '\u0574\u0576',
  0xfb14: '\u0574\u0565',
  0xfb15: '\u0574\u056b',
  0xfb16: '\u057e\u0576',
  0xfb17: '\u0574\u056d',
  0x1d400: 'a',
  0x1d401: 'b',
  0x1d402: 'c',
  0x1d403: 'd',
  0x1d404: 'e',
  0x1d405: 'f',
  0x1d406: 'g',
  0x1d407: 'h',
  0x1d408: 'i',
  0x1d409: 'j',
  0x1d40a: 'k',
  0x1d40b: 'l',
  0x1d40c: 'm',
  0x1d40d: 'n',
  0x1d40e: 'o',
  0x1d40f: 'p',
  0x1d410: 'q',
  0x1d411: 'r',
  0x1d412: 's',
  0x1d413: 't',
  0x1d414: 'u',
  0x1d415: 'v',
  0x1d416: 'w',
  0x1d417: 'x',
  0x1d418: 'y',
  0x1d419: 'z',
  0x1d434: 'a',
  0x1d435: 'b',
  0x1d436: 'c',
  0x1d437: 'd',
  0x1d438: 'e',
  0x1d439: 'f',
  0x1d43a: 'g',
  0x1d43b: 'h',
  0x1d43c: 'i',
  0x1d43d: 'j',
  0x1d43e: 'k',
  0x1d43f: 'l',
  0x1d440: 'm',
  0x1d441: 'n',
  0x1d442: 'o',
  0x1d443: 'p',
  0x1d444: 'q',
  0x1d445: 'r',
  0x1d446: 's',
  0x1d447: 't',
  0x1d448: 'u',
  0x1d449: 'v',
  0x1d44a: 'w',
  0x1d44b: 'x',
  0x1d44c: 'y',
  0x1d44d: 'z',
  0x1d468: 'a',
  0x1d469: 'b',
  0x1d46a: 'c',
  0x1d46b: 'd',
  0x1d46c: 'e',
  0x1d46d: 'f',
  0x1d46e: 'g',
  0x1d46f: 'h',
  0x1d470: 'i',
  0x1d471: 'j',
  0x1d472: 'k',
  0x1d473: 'l',
  0x1d474: 'm',
  0x1d475: 'n',
  0x1d476: 'o',
  0x1d477: 'p',
  0x1d478: 'q',
  0x1d479: 'r',
  0x1d47a: 's',
  0x1d47b: 't',
  0x1d47c: 'u',
  0x1d47d: 'v',
  0x1d47e: 'w',
  0x1d47f: 'x',
  0x1d480: 'y',
  0x1d481: 'z',
  0x1d49c: 'a',
  0x1d49e: 'c',
  0x1d49f: 'd',
  0x1d4a2: 'g',
  0x1d4a5: 'j',
  0x1d4a6: 'k',
  0x1d4a9: 'n',
  0x1d4aa: 'o',
  0x1d4ab: 'p',
  0x1d4ac: 'q',
  0x1d4ae: 's',
  0x1d4af: 't',
  0x1d4b0: 'u',
  0x1d4b1: 'v',
  0x1d4b2: 'w',
  0x1d4b3: 'x',
  0x1d4b4: 'y',
  0x1d4b5: 'z',
  0x1d4d0: 'a',
  0x1d4d1: 'b',
  0x1d4d2: 'c',
  0x1d4d3: 'd',
  0x1d4d4: 'e',
  0x1d4d5: 'f',
  0x1d4d6: 'g',
  0x1d4d7: 'h',
  0x1d4d8: 'i',
  0x1d4d9: 'j',
  0x1d4da: 'k',
  0x1d4db: 'l',
  0x1d4dc: 'm',
  0x1d4dd: 'n',
  0x1d4de: 'o',
  0x1d4df: 'p',
  0x1d4e0: 'q',
  0x1d4e1: 'r',
  0x1d4e2: 's',
  0x1d4e3: 't',
  0x1d4e4: 'u',
  0x1d4e5: 'v',
  0x1d4e6: 'w',
  0x1d4e7: 'x',
  0x1d4e8: 'y',
  0x1d4e9: 'z',
  0x1d504: 'a',
  0x1d505: 'b',
  0x1d507: 'd',
  0x1d508: 'e',
  0x1d509: 'f',
  0x1d50a: 'g',
  0x1d50d: 'j',
  0x1d50e: 'k',
  0x1d50f: 'l',
  0x1d510: 'm',
  0x1d511: 'n',
  0x1d512: 'o',
  0x1d513: 'p',
  0x1d514: 'q',
  0x1d516: 's',
  0x1d517: 't',
  0x1d518: 'u',
  0x1d519: 'v',
  0x1d51a: 'w',
  0x1d51b: 'x',
  0x1d51c: 'y',
  0x1d538: 'a',
  0x1d539: 'b',
  0x1d53b: 'd',
  0x1d53c: 'e',
  0x1d53d: 'f',
  0x1d53e: 'g',
  0x1d540: 'i',
  0x1d541: 'j',
  0x1d542: 'k',
  0x1d543: 'l',
  0x1d544: 'm',
  0x1d546: 'o',
  0x1d54a: 's',
  0x1d54b: 't',
  0x1d54c: 'u',
  0x1d54d: 'v',
  0x1d54e: 'w',
  0x1d54f: 'x',
  0x1d550: 'y',
  0x1d56c: 'a',
  0x1d56d: 'b',
  0x1d56e: 'c',
  0x1d56f: 'd',
  0x1d570: 'e',
  0x1d571: 'f',
  0x1d572: 'g',
  0x1d573: 'h',
  0x1d574: 'i',
  0x1d575: 'j',
  0x1d576: 'k',
  0x1d577: 'l',
  0x1d578: 'm',
  0x1d579: 'n',
  0x1d57a: 'o',
  0x1d57b: 'p',
  0x1d57c: 'q',
  0x1d57d: 'r',
  0x1d57e: 's',
  0x1d57f: 't',
  0x1d580: 'u',
  0x1d581: 'v',
  0x1d582: 'w',
  0x1d583: 'x',
  0x1d584: 'y',
  0x1d585: 'z',
  0x1d5a0: 'a',
  0x1d5a1: 'b',
  0x1d5a2: 'c',
  0x1d5a3: 'd',
  0x1d5a4: 'e',
  0x1d5a5: 'f',
  0x1d5a6: 'g',
  0x1d5a7: 'h',
  0x1d5a8: 'i',
  0x1d5a9: 'j',
  0x1d5aa: 'k',
  0x1d5ab: 'l',
  0x1d5ac: 'm',
  0x1d5ad: 'n',
  0x1d5ae: 'o',
  0x1d5af: 'p',
  0x1d5b0: 'q',
  0x1d5b1: 'r',
  0x1d5b2: 's',
  0x1d5b3: 't',
  0x1d5b4: 'u',
  0x1d5b5: 'v',
  0x1d5b6: 'w',
  0x1d5b7: 'x',
  0x1d5b8: 'y',
  0x1d5b9: 'z',
  0x1d5d4: 'a',
  0x1d5d5: 'b',
  0x1d5d6: 'c',
  0x1d5d7: 'd',
  0x1d5d8: 'e',
  0x1d5d9: 'f',
  0x1d5da: 'g',
  0x1d5db: 'h',
  0x1d5dc: 'i',
  0x1d5dd: 'j',
  0x1d5de: 'k',
  0x1d5df: 'l',
  0x1d5e0: 'm',
  0x1d5e1: 'n',
  0x1d5e2: 'o',
  0x1d5e3: 'p',
  0x1d5e4: 'q',
  0x1d5e5: 'r',
  0x1d5e6: 's',
  0x1d5e7: 't',
  0x1d5e8: 'u',
  0x1d5e9: 'v',
  0x1d5ea: 'w',
  0x1d5eb: 'x',
  0x1d5ec: 'y',
  0x1d5ed: 'z',
  0x1d608: 'a',
  0x1d609: 'b',
  0x1d60a: 'c',
  0x1d60b: 'd',
  0x1d60c: 'e',
  0x1d60d: 'f',
  0x1d60e: 'g',
  0x1d60f: 'h',
  0x1d610: 'i',
  0x1d611: 'j',
  0x1d612: 'k',
  0x1d613: 'l',
  0x1d614: 'm',
  0x1d615: 'n',
  0x1d616: 'o',
  0x1d617: 'p',
  0x1d618: 'q',
  0x1d619: 'r',
  0x1d61a: 's',
  0x1d61b: 't',
  0x1d61c: 'u',
  0x1d61d: 'v',
  0x1d61e: 'w',
  0x1d61f: 'x',
  0x1d620: 'y',
  0x1d621: 'z',
  0x1d63c: 'a',
  0x1d63d: 'b',
  0x1d63e: 'c',
  0x1d63f: 'd',
  0x1d640: 'e',
  0x1d641: 'f',
  0x1d642: 'g',
  0x1d643: 'h',
  0x1d644: 'i',
  0x1d645: 'j',
  0x1d646: 'k',
  0x1d647: 'l',
  0x1d648: 'm',
  0x1d649: 'n',
  0x1d64a: 'o',
  0x1d64b: 'p',
  0x1d64c: 'q',
  0x1d64d: 'r',
  0x1d64e: 's',
  0x1d64f: 't',
  0x1d650: 'u',
  0x1d651: 'v',
  0x1d652: 'w',
  0x1d653: 'x',
  0x1d654: 'y',
  0x1d655: 'z',
  0x1d670: 'a',
  0x1d671: 'b',
  0x1d672: 'c',
  0x1d673: 'd',
  0x1d674: 'e',
  0x1d675: 'f',
  0x1d676: 'g',
  0x1d677: 'h',
  0x1d678: 'i',
  0x1d679: 'j',
  0x1d67a: 'k',
  0x1d67b: 'l',
  0x1d67c: 'm',
  0x1d67d: 'n',
  0x1d67e: 'o',
  0x1d67f: 'p',
  0x1d680: 'q',
  0x1d681: 'r',
  0x1d682: 's',
  0x1d683: 't',
  0x1d684: 'u',
  0x1d685: 'v',
  0x1d686: 'w',
  0x1d687: 'x',
  0x1d688: 'y',
  0x1d689: 'z',
  0x1d6a8: '\u03b1',
  0x1d6a9: '\u03b2',
  0x1d6aa: '\u03b3',
  0x1d6ab: '\u03b4',
  0x1d6ac: '\u03b5',
  0x1d6ad: '\u03b6',
  0x1d6ae: '\u03b7',
  0x1d6af: '\u03b8',
  0x1d6b0: '\u03b9',
  0x1d6b1: '\u03ba',
  0x1d6b2: '\u03bb',
  0x1d6b3: '\u03bc',
  0x1d6b4: '\u03bd',
  0x1d6b5: '\u03be',
  0x1d6b6: '\u03bf',
  0x1d6b7: '\u03c0',
  0x1d6b8: '\u03c1',
  0x1d6b9: '\u03b8',
  0x1d6ba: '\u03c3',
  0x1d6bb: '\u03c4',
  0x1d6bc: '\u03c5',
  0x1d6bd: '\u03c6',
  0x1d6be: '\u03c7',
  0x1d6bf: '\u03c8',
  0x1d6c0: '\u03c9',
  0x1d6d3: '\u03c3',
  0x1d6e2: '\u03b1',
  0x1d6e3: '\u03b2',
  0x1d6e4: '\u03b3',
  0x1d6e5: '\u03b4',
  0x1d6e6: '\u03b5',
  0x1d6e7: '\u03b6',
  0x1d6e8: '\u03b7',
  0x1d6e9: '\u03b8',
  0x1d6ea: '\u03b9',
  0x1d6eb: '\u03ba',
  0x1d6ec: '\u03bb',
  0x1d6ed: '\u03bc',
  0x1d6ee: '\u03bd',
  0x1d6ef: '\u03be',
  0x1d6f0: '\u03bf',
  0x1d6f1: '\u03c0',
  0x1d6f2: '\u03c1',
  0x1d6f3: '\u03b8',
  0x1d6f4: '\u03c3',
  0x1d6f5: '\u03c4',
  0x1d6f6: '\u03c5',
  0x1d6f7: '\u03c6',
  0x1d6f8: '\u03c7',
  0x1d6f9: '\u03c8',
  0x1d6fa: '\u03c9',
  0x1d70d: '\u03c3',
  0x1d71c: '\u03b1',
  0x1d71d: '\u03b2',
  0x1d71e: '\u03b3',
  0x1d71f: '\u03b4',
  0x1d720: '\u03b5',
  0x1d721: '\u03b6',
  0x1d722: '\u03b7',
  0x1d723: '\u03b8',
  0x1d724: '\u03b9',
  0x1d725: '\u03ba',
  0x1d726: '\u03bb',
  0x1d727: '\u03bc',
  0x1d728: '\u03bd',
  0x1d729: '\u03be',
  0x1d72a: '\u03bf',
  0x1d72b: '\u03c0',
  0x1d72c: '\u03c1',
  0x1d72d: '\u03b8',
  0x1d72e: '\u03c3',
  0x1d72f: '\u03c4',
  0x1d730: '\u03c5',
  0x1d731: '\u03c6',
  0x1d732: '\u03c7',
  0x1d733: '\u03c8',
  0x1d734: '\u03c9',
  0x1d747: '\u03c3',
  0x1d756: '\u03b1',
  0x1d757: '\u03b2',
  0x1d758: '\u03b3',
  0x1d759: '\u03b4',
  0x1d75a: '\u03b5',
  0x1d75b: '\u03b6',
  0x1d75c: '\u03b7',
  0x1d75d: '\u03b8',
  0x1d75e: '\u03b9',
  0x1d75f: '\u03ba',
  0x1d760: '\u03bb',
  0x1d761: '\u03bc',
  0x1d762: '\u03bd',
  0x1d763: '\u03be',
  0x1d764: '\u03bf',
  0x1d765: '\u03c0',
  0x1d766: '\u03c1',
  0x1d767: '\u03b8',
  0x1d768: '\u03c3',
  0x1d769: '\u03c4',
  0x1d76a: '\u03c5',
  0x1d76b: '\u03c6',
  0x1d76c: '\u03c7',
  0x1d76d: '\u03c8',
  0x1d76e: '\u03c9',
  0x1d781: '\u03c3',
  0x1d790: '\u03b1',
  0x1d791: '\u03b2',
  0x1d792: '\u03b3',
  0x1d793: '\u03b4',
  0x1d794: '\u03b5',
  0x1d795: '\u03b6',
  0x1d796: '\u03b7',
  0x1d797: '\u03b8',
  0x1d798: '\u03b9',
  0x1d799: '\u03ba',
  0x1d79a: '\u03bb',
  0x1d79b: '\u03bc',
  0x1d79c: '\u03bd',
  0x1d79d: '\u03be',
  0x1d79e: '\u03bf',
  0x1d79f: '\u03c0',
  0x1d7a0: '\u03c1',
  0x1d7a1: '\u03b8',
  0x1d7a2: '\u03c3',
  0x1d7a3: '\u03c4',
  0x1d7a4: '\u03c5',
  0x1d7a5: '\u03c6',
  0x1d7a6: '\u03c7',
  0x1d7a7: '\u03c8',
  0x1d7a8: '\u03c9',
  0x1d7bb: '\u03c3',
};
