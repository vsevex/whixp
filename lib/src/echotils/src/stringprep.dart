import 'package:echox/echox.dart';
import 'package:echox/src/idna/idna.dart';
import 'package:echox/src/stringprep/stringprep.dart';
import 'package:memoize/memoize.dart';

class StringPreparationProfiles {
  final _nodePrep = StringPreparation().preps['nodeprep'];
  final _resourcePrep = StringPreparation().preps['resourceprep'];

  // Characters not allowed in a domain part
  final _illegalChars = '\x00\x01\x02\x03\x04\x05\x06\x07\x08\t\n\x0b\x0c\r'
      '\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19'
      '\x1a\x1b\x1c\x1d\x1e\x1f'
      ' !"#\$%&\'()*+,-./:;<=>?@[\\]^_`{|}~\x7f';

  String? nodePrep(String node) {
    if (_nodePrep == null) return null;
    final check = memo1((String node) => _nodePrep!(node));
    return check(node);
  }

  String? resourcePrep(String resource) {
    if (_resourcePrep == null) return null;
    final check = memo1((String resource) => _resourcePrep!(resource));
    return check(resource);
  }

  String idna(String domain) {
    final domainParts = <String>[];
    for (final label in domain.split('.')) {
      String newLabel = label;
      try {
        newLabel = IDNA.nameprep(newLabel);
        IDNA.toASCII(newLabel);
      } on Exception {
        throw StringPreparationException(
          'Unicode error occured while converting to ASCII',
        );
      }

      if (label.startsWith('xn--')) {
        newLabel = IDNA.toUnicode(label);
      }

      for (int i = 0; i < newLabel.length; i++) {
        final char = newLabel[i];
        if (_illegalChars.contains(char)) {
          throw StringPreparationException(
            'Domain contains illegal char: $char',
          );
        }
      }

      domainParts.add(newLabel);
    }

    return domainParts.join();
  }

  String punycode(String domain) {
    final domainParts = <String>[];
    for (final label in domain.split('.')) {
      String newLabel = label;
      try {
        newLabel = IDNA.nameprep(newLabel);
        IDNA.toASCII(newLabel);
      } on Exception {
        throw StringPreparationException(
          'Unicode error occured while converting to ASCII',
        );
      }

      for (int i = 0; i < newLabel.length; i++) {
        final char = newLabel[i];
        if (_illegalChars.contains(char)) {
          throw StringPreparationException(
            'Domain contains illegal char: $char',
          );
        }
      }

      domainParts.add(newLabel);
    }

    return domainParts.join();
  }
}
