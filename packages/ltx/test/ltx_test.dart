import 'package:ltx/ltx.dart';

import 'package:test/test.dart';
import 'package:xml/xml.dart' as xml;

void main() {
  late LTXEmitter emitter;

  setUp(() {
    emitter = LTXEmitter();
  });

  void emit() => emitter.write(
        xml.XmlDocument.parse(
          '<foo><bar>hert</bar></foo>',
        ).rootElement,
      );

  group('emitter methods test', () {
    test(
      'notifies start event correctly when fired',
      () {
        emitter.startEvent.addListener(
          (element) => expect(element.toXmlString(), equals('<foo/>')),
        );

        emit();
      },
    );

    test(
      'notifies ending xml stanza fired correctly',
      () {
        emitter.endEvent.addListener(
          (element) => expect(element.toXmlString(), equals('<foo/>')),
        );

        emit();
      },
    );

    test(
      'notifies when there is a text fired',
      () {
        emitter.textEvent
            .addListener((element) => expect(element.toXmlString(), 'hert'));

        emit();
      },
    );
  });
}
