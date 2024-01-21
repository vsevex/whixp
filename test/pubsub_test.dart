import 'package:test/test.dart';

import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/plugins/plugins.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/message.dart';

import 'package:xml/xml.dart' as xml;

import 'test_base.dart';

void main() {
  late IQ iq;
  late Message message;

  setUp(() {
    iq = IQ(generateID: false);
    message = Message();
  });

  group(
    'pubsub owner stanza set cases',
    () {
      test(
        'default stanza for pubsub owner test cases',
        () {
          final owner = iq['pubsub_owner'] as PubSubOwnerStanza;
          final def = owner['default'] as PubSubOwnerDefaultConfig;
          def['node'] = 'testnode';
          (def['form'] as Form).addField(
            variable: 'pubsub#title',
            formType: 'text-single',
            value: 'bang-bang',
          );

          check(
            iq,
            '<iq><pubsub xmlns="http://jabber.org/protocol/pubsub#owner"><default node="testnode"><x type="form" xmlns="jabber:x:data"><field type="text-single" var="pubsub#title"><value>bang-bang</value></field></x></default></pubsub></iq>',
            useValues: false,
          );
        },
      );

      test(
        'must properly set iq/pubsub_owner/delete stanza',
        () {
          final owner = iq['pubsub_owner'] as PubSubOwnerStanza;
          (owner['delete'] as PubSubOwnerDelete)['node'] = 'cartNode';
          check(
            iq,
            '<iq><pubsub xmlns="http://jabber.org/protocol/pubsub#owner"><delete node="cartNode"/></pubsub></iq>',
          );
        },
      );
    },
  );

  group('pubsub stanza test cases', () {
    test(
      'must set properly nested iq/pubsub/affiliations/affiliation',
      () {
        final aff1 = PubSubAffiliation();
        aff1['node'] = 'testnodefirst';
        aff1['affiliation'] = 'owner';
        final aff2 = PubSubAffiliation();
        aff2['node'] = 'testnodesecond';
        aff2['affiliation'] = 'publisher';
        ((iq['pubsub'] as PubSubStanza)['affiliations'] as PubSubAffiliations)
          ..add(aff1)
          ..add(aff2);

        check(
          iq,
          '<iq><pubsub xmlns="http://jabber.org/protocol/pubsub"><affiliations><affiliation affiliation="owner" node="testnodefirst"/><affiliation affiliation="publisher" node="testnodesecond"/></affiliations></pubsub></iq>',
        );
      },
    );

    test(
      'must set properly nested iq/pubsub/subsriptions/subscription',
      () {
        final sub1 = PubSubSubscription();
        sub1['node'] = 'testnodefirst';
        sub1['jid'] = JabberID('alyosha@localhost/mobile');
        final sub2 = PubSubSubscription();
        sub2['node'] = 'testnodesecond';
        sub2['jid'] = JabberID('vsevex@example.com/desktop');
        sub2['subscription'] = 'subscribed';
        ((iq['pubsub'] as PubSubStanza)['affiliations'] as PubSubAffiliations)
          ..add(sub1)
          ..add(sub2);

        check(
          iq,
          '<iq><pubsub xmlns="http://jabber.org/protocol/pubsub"><affiliations><subscription jid="alyosha@localhost/mobile" node="testnodefirst"/><subscription jid="vsevex@example.com/desktop" node="testnodesecond" subscription="subscribed"/></affiliations></pubsub></iq>',
        );
      },
    );

    test(
      'must set properly nested iq/pubsub/subscription/subscribe-options',
      () {
        final subscription = (iq['pubsub'] as PubSubStanza)['subscription']
            as PubSubSubscription;
        (subscription['suboptions'] as PubSubSubscribeOptions)['required'] =
            true;
        subscription['node'] = 'testnode';
        subscription['jid'] = JabberID('vsevex@example.com/desktop');
        subscription['subscription'] = 'unconfigured';
        check(
          iq,
          '<iq><pubsub xmlns="http://jabber.org/protocol/pubsub"><subscription jid="vsevex@example.com/desktop" node="testnode" subscription="unconfigured"><subscribe-options><required/></subscribe-options></subscription></pubsub></iq>',
          useValues: false,
        );
      },
    );

    test(
      'must set properly nested iq/pubsub/items stanza',
      () {
        final pubsub = iq['pubsub'] as PubSubStanza;
        (pubsub['items'] as PubSubItems)['node'] = 'cart';
        final payload = xml.XmlDocument.parse(
          '<element xmlns="http://jabber.org/protocol/proto" var="blya"><child prop="bar"/></element>',
        ).rootElement;
        final item = PubSubItem();
        item['id'] = 'id1';
        item['payload'] = payload;
        final itemSecond = PubSubItem();
        itemSecond['id'] = 'id2';
        (pubsub['items'] as PubSubItems)
          ..add(item)
          ..add(itemSecond);
        check(
          iq,
          '<iq><pubsub xmlns="http://jabber.org/protocol/pubsub"><items node="cart"><item id="id1"><element var="blya" xmlns="http://jabber.org/protocol/proto"><child prop="bar"/></element></item><item id="id2"/></items></pubsub></iq>',
        );
      },
    );

    test(
      'must set properly nested iq/pubsub/create&configure stanza',
      () {
        final pubsub = iq['pubsub'] as PubSubStanza;
        (pubsub['create'] as PubSubCreate)['node'] = 'testnode';
        ((pubsub['configure'] as PubSubConfigure)['form'] as Form).addField(
          variable: 'pubsub#title',
          formType: 'text-single',
          value: 'cartu desu',
        );

        check(
          iq,
          '<iq><pubsub xmlns="http://jabber.org/protocol/pubsub"><create node="testnode"/><configure><x type="form" xmlns="jabber:x:data"><field type="text-single" var="pubsub#title"><value>cartu desu</value></field></x></configure></pubsub></iq>',
        );
      },
    );

    test(
      'must set properly nested iq/pubsub/subscribe stanza',
      () {
        final pubsub = iq['pubsub'] as PubSubStanza;
        final subscribe = pubsub['subscribe'] as PubSubSubscribe;
        subscribe['jid'] = JabberID('alyosha@example.com/desktop');
        subscribe['node'] = 'firstnode';
        final options = subscribe['options'] as PubSubOptions;
        options['node'] = 'optionsnode';
        options['jid'] = JabberID('vsevex@localhost/embedded');
        final form = Form();
        form['type'] = 'submit';
        form.addField(
          variable: 'pubsub#title',
          formType: 'text-single',
          value: 'bang-bang',
        );
        options['options'] = form;

        check(
          iq,
          '<iq><pubsub xmlns="http://jabber.org/protocol/pubsub"><subscribe jid="alyosha@example.com/desktop" node="firstnode"><options jid="vsevex@localhost/embedded" node="optionsnode"><x type="submit" xmlns="jabber:x:data"><field var="pubsub#title"><value>bang-bang</value></field></x></options></subscribe></pubsub></iq>',
          useValues: false,
        );
      },
    );

    test(
      'must properly get config from full create',
      () {
        iq['to'] = 'alyosha@example.com';
        iq['from'] = 'vsevex@localhost/desktop';
        iq['type'] = 'set';
        iq['id'] = 'someId';

        final pub = iq['pubsub'] as PubSubStanza;
        final configure = pub['configure'] as PubSubConfigure;
        (pub['create'] as PubSubCreate)['node'] = 'testnode';
        final form = configure['form'] as Form;
        form.setType('submit');
        form.setFields(<String, Map<String, dynamic>>{
          'FORM_TYPE': {
            'type': 'hidden',
            'value': 'http://jabber.org/protocol/pubsub#node_config',
          },
          'pubsub#node_type': {
            'type': 'list-single',
            'label': 'Select the node type',
            'value': 'leaf',
          },
          'pubsub#title': {
            'type': 'text-single',
            'label': 'Name for the node',
          },
          'pubsub#deliver_notifications': {
            'type': 'boolean',
            'label': 'Event notifications',
            'value': true,
          },
          'pubsub#deliver_payloads': {
            'type': 'boolean',
            'label': 'Deliveer payloads with event notifications',
            'value': true,
          },
          'pubsub#notify_config': {
            'type': 'boolean',
            'label': 'Notify subscribers when the node configuration changes',
          },
          'pubsub#notify_delete': {
            'type': 'boolean',
            'label': 'Notify subscribers when the node is deleted',
          },
          'pubsub#notify_retract': {
            'type': 'boolean',
            'label': 'Notify subscribers when items are removed from the node',
            'value': true,
          },
          'pubsub#publish_model': {
            'type': 'list-single',
            'label': 'Specify the publisher model',
            'value': 'publishers',
          },
        });

        check(
          iq,
          '<iq from="vsevex@localhost/desktop" id="someId" to="alyosha@example.com" type="set"><pubsub xmlns="http://jabber.org/protocol/pubsub"><configure><x type="submit" xmlns="jabber:x:data"><field type="hidden" var="FORM_TYPE"><value>http://jabber.org/protocol/pubsub#node_config</value></field><field var="pubsub#node_type"><value>leaf</value></field><field var="pubsub#title"/><field var="pubsub#deliver_notifications"><value>1</value></field><field var="pubsub#deliver_payloads"><value>1</value></field><field var="pubsub#notify_config"/><field var="pubsub#notify_delete"/><field var="pubsub#notify_retract"><value>1</value></field><field var="pubsub#publish_model"><value>publishers</value></field></x></configure><create node="testnode"/></pubsub></iq>',
        );
      },
    );

    test(
      'must properly set message/pubsub_event/items/item stanza',
      () {
        final item = PubSubEventItem();
        final element = xml.XmlElement(
          xml.XmlName('test'),
          [
            xml.XmlAttribute(xml.XmlName('failed'), '3'),
            xml.XmlAttribute(xml.XmlName('passed'), '24'),
          ],
        )..setAttribute('xmlns', 'http://cartcurt.org/protocol/test');
        item['payload'] = element;
        item['id'] = 'someID';
        final items = (message['pubsub_event'] as PubSubEvent)['items']
            as PubSubEventItems;
        items.add(item);
        items['node'] = 'foo';
        message['type'] = 'normal';

        check(
          message,
          '<message type="normal"><event xmlns="http://jabber.org/protocol/pubsub#event"><items node="foo"><item id="someID"><test failed="3" passed="24" xmlns="http://cartcurt.org/protocol/test"/></item></items></event></message>',
        );
      },
    );

    test('multiple message/pubsub_event/items/item stanza', () {
      final item = PubSubEventItem();
      final itemSecond = PubSubEventItem();
      final payload = xml.XmlElement(
        xml.XmlName('test'),
        [
          xml.XmlAttribute(xml.XmlName('failed'), '3'),
          xml.XmlAttribute(xml.XmlName('passed'), '24'),
        ],
      )..setAttribute('xmlns', 'http://cartcurt.org/protocol/test');
      final payloadSecond = xml.XmlElement(
        xml.XmlName('test'),
        [
          xml.XmlAttribute(xml.XmlName('total'), '10'),
          xml.XmlAttribute(xml.XmlName('passed'), '27'),
        ],
      )..setAttribute('xmlns', 'http://cartcurt.org/protocol/test-other');
      itemSecond['payload'] = payloadSecond;
      item['payload'] = payload;
      item['id'] = 'firstID';
      itemSecond['id'] = 'secondID';
      final items =
          (message['pubsub_event'] as PubSubEvent)['items'] as PubSubEventItems;
      items
        ..add(item)
        ..add(itemSecond);
      items['node'] = 'foo';

      check(
        message,
        '<message><event xmlns="http://jabber.org/protocol/pubsub#event"><items node="foo"><item id="firstID"><test failed="3" passed="24" xmlns="http://cartcurt.org/protocol/test"/></item><item id="secondID"><test passed="27" total="10" xmlns="http://cartcurt.org/protocol/test-other"/></item></items></event></message>',
      );
    });

    test(
      'must properly set message/pubsub_event/items/item && retract mix',
      () {
        final item = PubSubEventItem();
        final itemSecond = PubSubEventItem();
        final payload = xml.XmlElement(
          xml.XmlName('test'),
          [
            xml.XmlAttribute(xml.XmlName('failed'), '3'),
            xml.XmlAttribute(xml.XmlName('passed'), '24'),
          ],
        )..setAttribute('xmlns', 'http://cartcurt.org/protocol/test');
        final payloadSecond = xml.XmlElement(
          xml.XmlName('test'),
          [
            xml.XmlAttribute(xml.XmlName('total'), '10'),
            xml.XmlAttribute(xml.XmlName('passed'), '27'),
          ],
        )..setAttribute('xmlns', 'http://cartcurt.org/protocol/test-other');
        itemSecond['payload'] = payloadSecond;
        final retract = PubSubEventRetract();
        retract['id'] = 'retractID';
        item['payload'] = payload;
        item['id'] = 'firstItemID';
        itemSecond['id'] = 'secondItemID';
        final items = (message['pubsub_event'] as PubSubEvent)['items']
            as PubSubEventItems;
        items
          ..add(item)
          ..add(retract)
          ..add(itemSecond);
        items['node'] = 'bar';
        message.normal();

        check(
          message,
          '<message type="normal"><event xmlns="http://jabber.org/protocol/pubsub#event"><items node="bar"><item id="firstItemID"><test failed="3" passed="24" xmlns="http://cartcurt.org/protocol/test"/></item><retract id="retractID"/><item id="secondItemID"><test passed="27" total="10" xmlns="http://cartcurt.org/protocol/test-other"/></item></items></event></message>',
        );
      },
    );

    test(
      'must properly set message/pubsub_event/collection/associate stanza',
      () {
        final collection = (message['pubsub_event']
            as PubSubEvent)['collection'] as PubSubEventCollection;
        (collection['associate'] as PubSubEventAssociate)['node'] = 'foo';
        collection['node'] = 'node';
        message['type'] = 'headline';

        check(
          message,
          '<message type="headline"><event xmlns="http://jabber.org/protocol/pubsub#event"><collection node="node"><associate node="foo"/></collection></event></message>',
        );
      },
    );

    test(
      'must properly set message/pubsub_event/collection/disassociate stanza',
      () {
        final collection = (message['pubsub_event']
            as PubSubEvent)['collection'] as PubSubEventCollection;
        (collection['disassociate'] as PubSubEventDisassociate)['node'] = 'foo';
        collection['node'] = 'node';
        message['type'] = 'headline';

        check(
          message,
          '<message type="headline"><event xmlns="http://jabber.org/protocol/pubsub#event"><collection node="node"><disassociate node="foo"/></collection></event></message>',
        );
      },
    );

    test(
      'must properly set message/pubsub_event/configuration/config stanza',
      () {
        final configuration = (message['pubsub_event']
            as PubSubEvent)['configuration'] as PubSubEventConfiguration;
        configuration['node'] = 'someNode';
        (configuration['form'] as Form).addField(
          variable: 'pubsub#title',
          formType: 'text-single',
          value: 'Some Value',
        );
        message['type'] = 'headline';

        check(
          message,
          '<message type="headline"><event xmlns="http://jabber.org/protocol/pubsub#event"><configuration node="someNode"><x type="form" xmlns="jabber:x:data"><field type="text-single" var="pubsub#title"><value>Some Value</value></field></x></configuration></event></message>',
        );
      },
    );

    test(
      'must properly set message/pubsub_event/purge stanza',
      () {
        final purge = (message['pubsub_event'] as PubSubEvent)['purge']
            as PubSubEventPurge;
        purge['node'] = 'someNode';
        message['type'] = 'headline';

        check(
          message,
          '<message type="headline"><event xmlns="http://jabber.org/protocol/pubsub#event"><purge node="someNode"/></event></message>',
        );
      },
    );

    test(
      'must properly set message/pubsub_event/subscription stanza',
      () {
        final subscription = (message['pubsub_event']
            as PubSubEvent)['subscription'] as PubSubEventSubscription;
        subscription['node'] = 'someNode';
        subscription['jid'] = JabberID('vsevex@exmaple.com/mobile');
        subscription['subid'] = 'someID';
        subscription['subscription'] = 'subscribed';
        subscription['expiry'] = 'presence';
        message['type'] = 'headline';
        check(
          message,
          '<message type="headline"><event xmlns="http://jabber.org/protocol/pubsub#event"><subscription expiry="presence" jid="vsevex@exmaple.com/mobile" node="someNode" subid="someID" subscription="subscribed"/></event></message>',
          useValues: false,
        );
      },
    );
  });
}
