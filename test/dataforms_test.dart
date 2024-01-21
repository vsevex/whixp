import 'package:test/test.dart';

import 'package:whixp/src/plugins/form/dataforms.dart';
import 'package:whixp/src/stanza/message.dart';

import 'test_base.dart';

void main() {
  late Message message;

  setUp(() => message = Message());

  group('data forms extension stanza manipulation test cases', () {
    test(
      'must properly set multiple instructions elements in a data form',
      () {
        (message['form'] as Form)['instructions'] =
            'Instructions\nSecond batch';

        check(
          message,
          '<message><x xmlns="jabber:x:data" type="form"><instructions>Instructions</instructions><instructions>Second batch</instructions></x></message>',
        );
      },
    );

    test('add field to a data form', () {
      final form = message['form'] as Form;
      form.addField(
        variable: 'aa',
        formType: 'text-single',
        label: 'cart',
        description: 'A cart field',
        required: true,
        value: 'inner value',
      );

      check(
        message,
        '<message><x type="form" xmlns="jabber:x:data"><field label="cart" type="text-single" var="aa"><value>inner value</value><desc>A cart field</desc><required/></field></x></message>',
      );

      final fields = <String, Map<String, dynamic>>{};
      fields['v1'] = <String, dynamic>{
        'type': 'text-single',
        'label': 'Username',
        'required': true,
      };

      form.setFields(fields);

      check(
        message,
        '<message><x type="form" xmlns="jabber:x:data"><field label="cart" type="text-single" var="aa"><value>inner value</value><desc>A cart field</desc><required/></field><field type="text-single" var="v1" label="Username"><required/></field></x></message>',
      );

      fields.clear();
      fields['v2'] = <String, dynamic>{
        'type': 'text-private',
        'label': 'Password',
        'required': true,
      };
      fields['v3'] = <String, dynamic>{
        'type': 'text-multi',
        'label': 'Message',
        'value': 'Enter message.\nCartu desu',
      };
      fields['v4'] = <String, dynamic>{
        'type': 'list-single',
        'label': 'Message Type',
        'options': <Map<String, String>>[
          {'label': 'gup', 'value': 'salam'},
        ],
      };

      form.setFields(fields);

      check(
        message,
        '<message><x type="form" xmlns="jabber:x:data"><field label="cart" type="text-single" var="aa"><value>inner value</value><desc>A cart field</desc><required/></field><field label="Username" type="text-single" var="v1"><required/></field><field label="Password" type="text-private" var="v2"><required/></field><field label="Message" type="text-multi" var="v3"><value>Enter message.</value><value>Cartu desu</value></field><field label="Message Type" type="list-single" var="v4"><option label="gup"><value>salam</value></option></field></x></message>',
      );
    });

    test('must properly set form values', () {
      final form = message['form'] as Form;

      form
        ..addField(variable: 'foo', formType: 'text-single')
        ..addField(variable: 'bar', formType: 'list-multi')
        ..setValues({
          'foo': 'salam',
          'bar': ['a', 'b', 'c'],
        });

      check(
        message,
        '<message><x type="form" xmlns="jabber:x:data"><field type="text-single" var="foo"><value>salam</value></field><field type="list-multi" var="bar"><value>a</value><value>b</value><value>c</value></field></x></message>',
      );
    });

    test('setting type to "submit" must clear extra details', () {
      final form = message['form'] as Form;
      final fields = <String, Map<String, dynamic>>{};
      fields['v1'] = {
        'type': 'text-single',
        'label': 'Username',
        'required': true,
      };
      fields['v2'] = {
        'type': 'text-private',
        'label': 'Password',
        'required': true,
      };
      fields['v3'] = {
        'type': 'text-multi',
        'label': 'Message',
        'value': 'Enter message.\nA long one even.',
      };
      fields['v4'] = {
        'type': 'list-single',
        'label': 'Message Type',
        'options': [
          {
            'label': 'gup!',
            'value': 'cart',
          },
          {'label': 'heh', 'value': 'lerko'},
        ],
      };

      form
        ..setFields(fields)
        ..setType('submit')
        ..setValues({
          'v1': 'username',
          'v2': 'passwd',
          'v3': 'Message\nagain',
          'v4': 'helemi',
        });

      check(
        message,
        '<message><x type="submit" xmlns="jabber:x:data"><field var="v1"><value>username</value></field><field var="v2"><value>passwd</value></field><field var="v3"><value>Message</value><value>again</value></field><field var="v4"><value>helemi</value></field></x></message>',
      );
    });

    test('cancel type test', () {
      final form = message['form'] as Form;
      final fields = <String, Map<String, dynamic>>{};
      fields['v1'] = {
        'type': 'text-single',
        'label': 'Username',
        'required': true,
      };
      fields['v2'] = {
        'type': 'text-private',
        'label': 'Password',
        'required': true,
      };
      fields['v3'] = {
        'type': 'text-multi',
        'label': 'Message',
        'value': 'Enter message.\nA long one even.',
      };
      fields['v4'] = {
        'type': 'list-single',
        'label': 'Message Type',
        'options': [
          {
            'label': 'gup!',
            'value': 'cart',
          },
          {'label': 'heh', 'value': 'lerko'},
        ],
      };

      form.setFields(fields);
      form.setType('cancel');

      check(
        message,
        '<message><x type="cancel" xmlns="jabber:x:data"/></message>',
      );
    });

    test('must properly assign <reported>', () {
      final form = message['form'] as Form;
      form
        ..setType('result')
        ..addReported(
          'a1',
          formType: 'text-single',
          label: 'Username',
        )
        ..addItem({'a1': 'vsevex@example.com'});

      check(
        message,
        '<message><x type="result" xmlns="jabber:x:data"><reported><field label="Username" type="text-single" var="a1"/></reported><item><field var="a1"><value>vsevex@example.com</value></field></item></x></message>',
        useValues: false,
      );
    });

    test('must properly set all the defined reported', () {
      final form = message['form'] as Form;
      form.setType('result');

      final reported = <String, Map<String, dynamic>>{
        'v1': {
          'var': 'v1',
          'type': 'text-single',
          'label': 'Username',
        },
      };

      form.setReported(reported);

      check(
        message,
        '<message><x type="result" xmlns="jabber:x:data"><reported><field label="Username" type="text-single" var="v1"/></reported></x></message>',
      );
    });
  });
}
