import 'package:echox/src/echotils/src/idna.dart';
import 'package:test/test.dart';

void main() {
  group('string preparation IDNA test cases', () {
    test('Case folding ASCII U+0043 U+0041 U+0046 U+0045', () {
      const original = 'CAFE';
      const expected = 'cafe';

      final nameprop = IDNA.nameprep(original);
      expect(nameprop, equals(expected));
    });
  });
}
