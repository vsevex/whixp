// import 'package:test/test.dart';

// import 'package:whixp/src/handler/handler.dart';
// import 'package:whixp/src/stream/matcher/matcher.dart';
// import 'package:whixp/src/transport.dart';

// void main() {
//   late Transport transport;

//   setUpAll(() {
//     transport = testTransport();
//   });

//   group('using handlers', () {
//     test('stream callback handlers must catch upcoming stanza', () async {
//       final callback = CallbackHandler(
//         'Test',
//         (stanza) {
//           transport.sendRaw('<message><body>hert</body></message>');
//         },
//         matcher: XPathMatcher('<test xmlns="tester"/>'),
//       );

//       transport.registerHandler(callback);

//       await receive('<test xmlns="tester"/>', transport);
//     });
//   });
// }
