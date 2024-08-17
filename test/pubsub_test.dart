import 'package:test/test.dart';

import 'package:whixp/src/plugins/pubsub/pubsub.dart';

import 'package:xml/xml.dart' as xml;

void main() {
  group('pep tune test cases', () {
    test('must properly parse the given tune', () {
      const stanzaString =
          '<tune xmlns="http://jabber.org/protocol/tune"><artist>Yes</artist><length>686</length><rating>8</rating><source>Yessongs</source><title>Heart of the Sunrise</title><track>3</track><uri>http://www.yesworld.com/lyrics/Fragile.html#9</uri></tune>';
      final stanza = xml.XmlDocument.parse(stanzaString).rootElement;

      final tune = Tune.fromXML(stanza);

      expect(tune.artist, isNotNull);
      expect(tune.artist, equals('Yes'));
      expect(tune.length, isNotNull);
      expect(tune.length, equals(686));
      expect(tune.rating, isNotNull);
      expect(tune.rating, equals(8));
      expect(tune.source, isNotNull);
      expect(tune.source, equals('Yessongs'));
      expect(tune.title, isNotNull);
      expect(tune.title, equals('Heart of the Sunrise'));
      expect(tune.track, isNotNull);
      expect(tune.track, equals('3'));
      expect(tune.uri, isNotNull);
      expect(tune.uri, equals('http://www.yesworld.com/lyrics/Fragile.html#9'));
    });

    test('must properly convert the given xml to the tune stanza', () {
      const stanzaString =
          '<tune xmlns="http://jabber.org/protocol/tune"><artist>Yes</artist><length>686</length><rating>8</rating><source>Yessongs</source><title>Heart of the Sunrise</title><track>3</track><uri>http://www.yesworld.com/lyrics/Fragile.html#9</uri></tune>';
      final stanza = xml.XmlDocument.parse(stanzaString).rootElement;

      final parsed = Tune.fromXML(stanza);
      final fromParsed = parsed.toXML();

      expect(fromParsed.toXmlString(), equals(stanzaString));
    });

    test('must properly create stanza from constructor', () {
      const tune =
          Tune(artist: 'vsevex', length: 543, rating: 10, title: 'Without you');

      final toString = tune.toXMLString();

      expect(
        toString,
        '<tune xmlns="http://jabber.org/protocol/tune"><artist>vsevex</artist><length>543</length><rating>10</rating><title>Without you</title></tune>',
      );
    });
  });

  group('pep mood test cases', () {
    test('must properly parse from the given xml string', () {
      const stanzaString =
          '<mood xmlns="http://jabber.org/protocol/mood"><happy/><text>Yay, the mood spec has been approved!</text></mood>';

      final mood =
          Mood.fromXML(xml.XmlDocument.parse(stanzaString).rootElement);

      expect(mood.text, equals('Yay, the mood spec has been approved!'));
      expect(mood.value, equals('happy'));
    });

    test('must properly convert the given xml to the mood stanza', () {
      const stanzaString =
          '<mood xmlns="http://jabber.org/protocol/mood"><happy/><text>Yay, the mood spec has been approved!</text></mood>';
      final stanza = xml.XmlDocument.parse(stanzaString).rootElement;

      final parsed = Mood.fromXML(stanza);
      final fromParsed = parsed.toXML();

      expect(fromParsed.toXmlString(), equals(stanzaString));
    });
  });
}
