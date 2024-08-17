import 'package:test/test.dart';
import 'package:whixp/src/plugins/form/form.dart';

import 'package:whixp/src/stanza/message.dart';

import 'test_base.dart';

void main() {
  late Message message;

  setUp(() => message = Message());

  group('data forms extension stanza manipulation test cases', () {
    test(
      'must properly set instructions element in a data form',
      () {
        message.addPayload(Form(instructions: 'Instructions'));

        check(
          message,
          Message.fromXML(message.toXML()),
          '<message><x xmlns="jabber:x:data" type="form"><instructions>Instructions</instructions></x></message>',
        );
      },
    );

    test(
      'add field to a data form',
      () {
        final field = Field(
          variable: 'a',
          type: FieldType.textSingle,
          label: 'label',
          description: 'some description',
          required: true,
          values: ['inner value'],
        );

        final form = Form()..addFields([field]);

        message.addPayload(form);

        check(
          message,
          Message.fromXML(message.toXML()),
          '<message><x type="form" xmlns="jabber:x:data"><field label="label" type="text-single" var="a"><value>inner value</value><desc>some description</desc><required/></field></x></message>',
        );

        final secondField = Field(
          variable: 'aa',
          type: FieldType.textSingle,
          label: 'Username',
          required: true,
        );

        form.addFields([secondField]);

        check(
          message,
          Message.fromXML(secondField.toXML()),
          '<message><x type="form" xmlns="jabber:x:data"><field label="label" type="text-single" var="a"><value>inner value</value><desc>some description</desc><required/></field><field type="text-single" var="aa" label="Username"><required/></field></x></message>',
        );

        form.clearFields();

        check(
          message,
          Message.fromXML(message.toXML()),
          '<message><x type="form" xmlns="jabber:x:data"></x></message>',
        );
      },
    );

    test('must properly set form values', () {
      final form = Form();
      final firstField = Field(variable: 'foo', type: FieldType.textSingle);
      firstField.values.add('salam');
      final secondField = Field(variable: 'bar', type: FieldType.listMulti);
      secondField.values.addAll(['a', 'b', 'c']);

      form.addFields([firstField, secondField]);

      message.addPayload(form);

      check(
        message,
        Message.fromXML(message.toXML()),
        '<message><x type="form" xmlns="jabber:x:data"><field type="text-single" var="foo"><value>salam</value></field><field type="list-multi" var="bar"><value>a</value><value>b</value><value>c</value></field></x></message>',
      );
    });

    test('setting type to "submit" must clear extra details', () {
      final form = Form(type: FormType.submit);
      final first = Field(
        type: FieldType.textSingle,
        variable: 'v1',
        label: 'Username',
        required: true,
      );
      final second = Field(
        variable: 'v2',
        type: FieldType.textPrivate,
        label: 'Password',
        required: true,
      );
      final third = Field(
        variable: 'v3',
        type: FieldType.textMulti,
        label: 'Message',
      );
      third.values.add('Enter message');
      final fourth = Field(
        variable: 'v4',
        type: FieldType.listSingle,
        label: 'Message Type',
      );
      fourth.options.add(const FieldOption('option1', 'value'));
      form.addFields([first, second, third, fourth]);
      message.addPayload(form);

      expect(
        message.toXMLString(),
        equals(Message.fromXML(message.toXML()).toXMLString()),
      );
    });

    test('must properly assign <reported>', () {
      final form = Form(
        type: FormType.result,
        reported:
            Field(variable: 'a', type: FieldType.textSingle, label: 'Username'),
      );

      message.addPayload(form);

      expect(
        message.toXMLString(),
        Message.fromXML(message.toXML()).toXMLString(),
      );
    });
  });
}
