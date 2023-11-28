import 'package:echox/src/echotils/echotils.dart';

import 'package:test/test.dart';
import 'package:xml/xml.dart' as xml;

void main() {
  /// Compare the result of calling tostring against an expected result.
  void try2String(
    String original, {
    String? expected,
    String message = '',
  }) {
    expected ??= original;
    final element = xml.XmlDocument.parse(original).rootElement;

    final result = Echotils.serialize(element);
    expect(result, expected, reason: '$message: $result');
  }

  group('tostring method test cases', () {
    test(
      'test converting an empty element to a string',
      () => try2String(
        '<lerko xmlns="hert"/>',
        message: 'empty element not serialized correctly',
      ),
    );

    test(
      'must convert an empty element inside another element',
      () => try2String(
        '<lerko xmlns="hert"><blya/></lerko>',
        message: 'wrapped empty element not serialized correctly',
      ),
    );

    test(
      'convert an empty element wrapped with text inside another element',
      () => try2String(
        '<lerko xmlns="hert">hi!. <baz/> Everything will be allright.</lerko>',
        message: 'text wrapped empty element serialized incorrectly',
      ),
    );

    test(
      'must convert multiple child elements to a Unicode string',
      () => try2String(
        '<lerko xmlns="hert"><zort><qax/></zort><hehe/></lerko>',
      ),
    );

    test(
      'ensure that elements of the form <a>lerko <b>hert</b> blya</a> only include " blya" once',
      () => try2String(
        '<a>lerko <b>hert</b> blya</a>',
        message: 'element tail content is incorrect',
      ),
    );
  });
}
