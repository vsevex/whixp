// import 'package:test/test.dart';

// import 'package:whixp/src/plugins/rsm/rsm.dart';

// import 'package:xml/xml.dart' as xml;

// import 'test_base.dart';

// void main() {
//   late RSMStanza rsm;

//   setUp(() => rsm = RSMStanza());

//   group('Result Set Management plugin stanza test cases', () {
//     test('must properly set first index', () {
//       rsm['first'] = 'id';
//       rsm.setFirstIndex('10');

//       check(
//         rsm,
//         '<set xmlns="http://jabber.org/protocol/rsm"><first index="10">id</first></set>',
//       );
//     });

//     test('must properly get first index', () {
//       const elementString =
//           '<set xmlns="http://jabber.org/protocol/rsm"><first index="10">id</first></set>';

//       final stanza =
//           RSMStanza(element: xml.XmlDocument.parse(elementString).rootElement)
//               .firstIndex;
//       expect(stanza, equals('10'));
//     });

//     test('must properly delete first index', () {
//       const elementString =
//           '<set xmlns="http://jabber.org/protocol/rsm"><first index="10">id</first></set>';

//       final stanza =
//           RSMStanza(element: xml.XmlDocument.parse(elementString).rootElement)
//             ..deleteFirstIndex();

//       check(
//         stanza,
//         '<set xmlns="http://jabber.org/protocol/rsm"><first>id</first></set>',
//       );
//     });

//     test('must properly set before interface', () {
//       rsm.setBefore(true);

//       check(rsm, '<set xmlns="http://jabber.org/protocol/rsm"><before/></set>');
//     });

//     test('must return true if there is not any text associated', () {
//       const elementString =
//           '<set xmlns="http://jabber.org/protocol/rsm"><before/></set>';

//       final stanza =
//           RSMStanza(element: xml.XmlDocument.parse(elementString).rootElement);

//       expect(stanza.before, isTrue);
//     });

//     test('remove before interface', () {
//       const elementString =
//           '<set xmlns="http://jabber.org/protocol/rsm"><before/></set>';

//       final stanza =
//           RSMStanza(element: xml.XmlDocument.parse(elementString).rootElement)
//             ..delete('before');

//       check(
//         stanza,
//         '<set xmlns="http://jabber.org/protocol/rsm"></set>',
//       );
//     });

//     test('must properly set before interface with value', () {
//       rsm['before'] = 'value';

//       check(
//         rsm,
//         '<set xmlns="http://jabber.org/protocol/rsm"><before>value</before></set>',
//       );
//     });

//     test('must return proper text associated', () {
//       const elementString =
//           '<set xmlns="http://jabber.org/protocol/rsm"><before>value</before></set>';

//       final stanza =
//           RSMStanza(element: xml.XmlDocument.parse(elementString).rootElement);

//       expect(stanza['before'], equals('value'));
//     });
//   });
// }
