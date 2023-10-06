import 'package:echox/src/stringprep/stringprep.dart';

import 'package:test/test.dart';

void main() {
  group('string preparation table check methods test', () {
    test('mapTableb2 must return check result correctly', () {
      expect(
        StandaloneStringPreparation.mapTableb2('\u0041'),
        equals('\u0061'),
      );
      expect(
        StandaloneStringPreparation.mapTableb2('\u0061'),
        equals('\u0061'),
      );
    });
    test('mapTableb3 must return check result correctly', () {
      expect(
        StandaloneStringPreparation.mapTableb3('\u0041'),
        equals('\u0061'),
      );
      expect(
        StandaloneStringPreparation.mapTableb3('\u0061'),
        equals('\u0061'),
      );
    });
    test(
      'inTableb1 must check availability correct',
      () {
        expect(StandaloneStringPreparation.inTableb1('\u00ad'), isTrue);
        expect(StandaloneStringPreparation.inTableb1('\u00ae'), isFalse);
      },
    );
    test(
      'inTablec11 must return check result correctly',
      () {
        expect(StandaloneStringPreparation.inTablec11('\u0020'), isTrue);
        expect(StandaloneStringPreparation.inTablec11('\u0021'), isFalse);
      },
    );
    test(
      'inTablec12 must return check result correctly',
      () {
        expect(StandaloneStringPreparation.inTablec12('\u00a0'), isTrue);
        expect(StandaloneStringPreparation.inTablec12('\u0020'), isTrue);
        expect(StandaloneStringPreparation.inTablec12('\u00A0'), isTrue);
        expect(StandaloneStringPreparation.inTablec12('\u2002'), isTrue);

        expect(StandaloneStringPreparation.inTablec12('\u00a1'), isFalse);
        expect(StandaloneStringPreparation.inTablec12('A'), isFalse);
        expect(StandaloneStringPreparation.inTablec12('\n'), isFalse);
        expect(StandaloneStringPreparation.inTablec12('\t'), isFalse);
        expect(StandaloneStringPreparation.inTablec12('\u3000'), isFalse);
      },
    );
    test(
      'inTablec22 must return check result correctly',
      () {
        expect(StandaloneStringPreparation.inTablec22('\u009f'), isTrue);
        expect(StandaloneStringPreparation.inTablec22('\u00a0'), isFalse);
      },
    );
    test(
      'inTablec3 must return check result correctly',
      () {
        expect(StandaloneStringPreparation.inTablec3('\ue000'), isTrue);
        expect(StandaloneStringPreparation.inTablec3('\uf8ff'), isTrue);
        expect(StandaloneStringPreparation.inTablec3('\uf900'), isFalse);
        expect(StandaloneStringPreparation.inTablec3('A'), isFalse);
        expect(StandaloneStringPreparation.inTablec3('\n'), isFalse);
        expect(StandaloneStringPreparation.inTablec3('\t'), isFalse);
      },
    );
    test(
      'inTablec4 must return check result correctly',
      () {
        expect(StandaloneStringPreparation.inTablec4('\uffff'), isTrue);
        expect(StandaloneStringPreparation.inTablec4('\u0000'), isFalse);
      },
    );
    test(
      'inTablec5 must return check result correctly',
      () {
        expect(StandaloneStringPreparation.inTablec5('\ud800'), isTrue);
        expect(StandaloneStringPreparation.inTablec5('\udbff'), isTrue);
        expect(StandaloneStringPreparation.inTablec5('\udc00'), isTrue);
        expect(StandaloneStringPreparation.inTablec5('\ud7ff'), isFalse);
        expect(StandaloneStringPreparation.inTablec5('\uFFFF'), isFalse);
        expect(StandaloneStringPreparation.inTablec5('\u0010FFFF'), isFalse);
      },
    );
    test(
      'inTablec6 must return check result correctly',
      () {
        expect(StandaloneStringPreparation.inTablec6('\ufff9'), isTrue);
        expect(StandaloneStringPreparation.inTablec6('\ufffe'), isFalse);
      },
    );
    test(
      'inTablec7 must return check result correctly',
      () {
        expect(StandaloneStringPreparation.inTablec7('\u2ff0'), isTrue);
        expect(StandaloneStringPreparation.inTablec7('\u2ffc'), isFalse);
      },
    );
    test(
      'inTablec8 must return check result correctly',
      () {
        expect(StandaloneStringPreparation.inTablec8('\u0340'), isTrue);
        expect(StandaloneStringPreparation.inTablec8('\u0342'), isFalse);
      },
    );
    test(
      'inTabled1 must return check result correctly',
      () {
        expect(StandaloneStringPreparation.inTabled1('\u05be'), isTrue);
        expect(StandaloneStringPreparation.inTabled1('\u08bf'), isFalse);
      },
    );
    test(
      'inTabled2 must return check result correctly',
      () {
        expect(StandaloneStringPreparation.inTabled2('\u0041'), isTrue);
        expect(StandaloneStringPreparation.inTabled2('\u0040'), isFalse);
      },
    );
  });
}
