import 'package:test/test.dart';

import 'package:whixp/src/_static.dart';
import 'package:whixp/src/stanza/error.dart';

void main() {
  group('error stanza test cases', () {
    test('must generate presence and attach attributes', () {
      final error = ErrorStanza();

      error
        ..code = 404
        ..type = errorCancel
        ..reason = "item-not-found"
        ..text = "Item not found";

      final xml = error.toXML();

      expect(
        xml.toString(),
        equals(
          '<error type="cancel" code="404" xmlns="urn:ietf:params:xml:ns:xmpp-stanzas"><reason>item-not-found</reason><text>Item not found</text></error>',
        ),
      );
      final fromXML = ErrorStanza.fromXML(xml);
      expect(fromXML.code, isNotNull);
      expect(fromXML.code, 404);
      expect(fromXML.reason, isNotNull);
      expect(fromXML.reason, 'item-not-found');
      expect(fromXML.type, isNotNull);
      expect(fromXML.type, errorCancel);
    });
  });
}
