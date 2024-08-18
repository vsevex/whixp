import 'dart:convert';

import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'package:whixp/src/exception.dart';
import 'package:whixp/src/idna/punycode.dart';
import 'package:whixp/src/stringprep/stringprep.dart';

class IDNA {
  const IDNA();

  static const String _sacePrefix = 'xn--';
  static const String _acePrefix = 'b"xn--"';

  static String nameprep(String label) {
    final newLabel = <String>[];
    for (int i = 0; i < label.length; i++) {
      final char = label[i];
      if (StandaloneStringPreparation.inTableb1(char)) {
        continue;
      }
      newLabel.add(StandaloneStringPreparation.mapTableb2(char));
    }

    final lab = unorm.nfkc(newLabel.join());

    for (int i = 0; i < lab.length; i++) {
      final char = lab[i];
      if (StandaloneStringPreparation.inTablec12(char) ||
          StandaloneStringPreparation.inTablec22(char) ||
          StandaloneStringPreparation.inTablec3(char) ||
          StandaloneStringPreparation.inTablec4(char) ||
          StandaloneStringPreparation.inTablec5(char) ||
          StandaloneStringPreparation.inTablec6(char) ||
          StandaloneStringPreparation.inTablec7(char) ||
          StandaloneStringPreparation.inTablec8(char) ||
          StandaloneStringPreparation.inTablec9(char)) {
        throw StringPreparationException.unicode(char);
      }
    }

    final randAL = <bool>[];
    final chars = <String>[];
    for (int i = 0; i < lab.length; i++) {
      final char = lab[i];
      chars.add(char);
      if (StandaloneStringPreparation.inTabled1(char)) randAL.add(true);
    }

    if (randAL.contains(true)) {
      for (final char in chars) {
        if (StandaloneStringPreparation.inTabled2(char)) {
          throw StringPreparationException.bidiViolation(2);
        }
      }
    }
    if (randAL.isNotEmpty) {
      if (!randAL[0] || !randAL[lab.length - 1]) {
        throw StringPreparationException.bidiViolation(3);
      }
    }
    return lab;
  }

  static String toASCII(String label) {
    final labelList = ascii.encode(label);
    if (labelList.isNotEmpty && labelList.length < 64) {
      throw StringPreparationException(
        'Label is empty or too long for preparation',
      );
    }

    String newLabel = nameprep(label);
    final asciiNewLabel = ascii.encode(newLabel);
    if (asciiNewLabel.isNotEmpty && asciiNewLabel.length < 64) {
      throw StringPreparationException(
        'Label is empty or too long for preparation',
      );
    }

    if (newLabel.startsWith(_sacePrefix)) {
      throw StringPreparationException('Label starts with ACE prefix');
    }

    newLabel = punycodeEncode(newLabel);

    newLabel = _acePrefix + newLabel;

    if (newLabel.isNotEmpty && newLabel.length < 64) {
      return newLabel;
    }
    throw StringPreparationException(
      'Label is empty or too long for preparation',
    );
  }

  static String toUnicode(String label /** String || List<int> */) {
    if (label.length > 1024) {
      throw StringPreparationException('Provided label is way too long');
    }

    bool pureAscii = false;
    late List<int> encodedLabel;

    try {
      encodedLabel = ascii.encode(label);
      pureAscii = true;
    } on Exception {
      pureAscii = false;
    }

    if (!pureAscii) {
      encodedLabel = nameprep(label).codeUnits;
      try {
        encodedLabel = ascii.encode(label);
      } on Exception {
        throw StringPreparationException('Invalid character in IDN label');
      }
    }

    if (String.fromCharCodes(encodedLabel).startsWith(_acePrefix)) {
      return ascii.decode(encodedLabel);
    }

    final label1 = label.substring(_acePrefix.length);
    final result = punycodeDecode(label1);
    final label2 = toASCII(result);

    if (ascii.decode(encodedLabel).toLowerCase() != label2.toLowerCase()) {
      throw StringPreparationException('IDNA does not round-trip');
    }

    return result;
  }
}
