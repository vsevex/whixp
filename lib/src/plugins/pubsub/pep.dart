part of 'pubsub.dart';

/// The Tune class represents a musical tune and extends the [MessageStanza]
/// class.
///
/// It contains several properties related to the tune such as artist, length,
/// rating, source, title, track, and URI. The class also includes methods to
/// convert from and to XML.
///
/// Information about tunes is provided by the user and propagated on the
/// network by the user's client. The information container for tune data is a
/// tune element that is qualified by the 'http://jabber.org/protocol/tune'
/// namespace.
///
/// For more information refer to: <https://xmpp.org/extensions/xep-0118.html>
///
/// ### Example:
/// ```xml
/// <tune xmlns='http://jabber.org/protocol/tune'>
///   <artist>Yes</artist>
///   <length>686</length>
///   <rating>8</rating>
///   <source>Yessongs</source>
///   <title>Heart of the Sunrise</title>
///   <track>3</track>
///   <uri>http://www.yesworld.com/lyrics/Fragile.html#9</uri>
/// </tune>
/// ```
class Tune extends MessageStanza {
  const Tune({
    this.artist,
    this.length,
    this.rating,
    this.source,
    this.title,
    this.track,
    this.uri,
  });

  /// The name of the artist.
  final String? artist;

  /// The length of the tune in seconds.
  final int? length;

  /// The rating of the tune.
  final int? rating;

  /// The source of the tune.
  final String? source;

  /// The title of the tune.
  final String? title;

  /// The track number.
  final String? track;

  /// The URI of the tune.
  final String? uri;

  /// Creates an instance of [Tune] from an XML element. This constructor parses
  /// the XML element and sets the corresponding properties of the Tune object.
  factory Tune.fromXML(xml.XmlElement node) {
    String? artist;
    int? length;
    int? rating;
    String? source;
    String? title;
    String? track;
    String? uri;

    for (final child in node.children.whereType<xml.XmlElement>()) {
      switch (child.localName) {
        case 'artist':
          artist = child.innerText;
        case 'length':
          length = int.parse(child.innerText);
        case 'rating':
          rating = int.parse(child.innerText);
        case 'source':
          source = child.innerText;
        case 'title':
          title = child.innerText;
        case 'track':
          track = child.innerText;
        case 'uri':
          uri = child.innerText;
      }
    }

    return Tune(
      artist: artist,
      length: length,
      rating: rating,
      source: source,
      title: title,
      track: track,
      uri: uri,
    );
  }

  @override
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();

    builder.element(
      name,
      attributes: <String, String>{
        'xmlns': 'http://jabber.org/protocol/tune',
      },
      nest: () {
        if (artist?.isNotEmpty ?? false) {
          builder.element('artist', nest: () => builder.text(artist!));
        }
        if (length != null) {
          builder.element(
            'length',
            nest: () => builder.text(length!.toString()),
          );
        }
        if (rating != null) {
          builder.element(
            'rating',
            nest: () => builder.text(rating!.toString()),
          );
        }
        if (source?.isNotEmpty ?? false) {
          builder.element('source', nest: () => builder.text(source!));
        }
        if (title?.isNotEmpty ?? false) {
          builder.element('title', nest: () => builder.text(title!));
        }
        if (track?.isNotEmpty ?? false) {
          builder.element('track', nest: () => builder.text(track!));
        }
        if (uri?.isNotEmpty ?? false) {
          builder.element('uri', nest: () => builder.text(uri!));
        }
      },
    );

    return builder.buildDocument().rootElement;
  }

  @override
  String get name => 'tune';

  @override
  String get tag => tuneTag;
}

/// Represents a mood and extends the [MessageStanza] class. It contains
/// properties related to the mood such as value and text.
///
/// The class also includes methods to convert from and to XML.
///
/// Information about user moods is provided by the user and propagated on the
/// network by the user's client. The information is structured via a mood
/// element that is qualified by the 'http://jabber.org/protocol/mood'
/// namespace. The mood itself is provided as the element name of a defined
/// child element of the mood element (e.g., happy); one such child
/// element is REQUIRED.
///
/// ### Example:
/// ```xml
/// <mood xmlns='http://jabber.org/protocol/mood'>
//   <happy/>
//   <text>Yay, the mood spec has been approved!</text>
// </mood>
/// ```
class Mood extends MessageStanza {
  const Mood({this.value, this.text});

  /// The value of the mood.
  final String? value;

  /// Additional text describing the mood.
  final String? text;

  /// Creates an instance of [Mood] from an XML element. This constructor parses
  /// the XML element and sets the corresponding properties of the Mood object.
  factory Mood.fromXML(xml.XmlElement node) {
    String? text;
    String? value;

    for (final child in node.children.whereType<xml.XmlElement>()) {
      if (child.localName == 'text') {
        text = child.innerText;
      } else {
        value = child.localName;
      }
    }

    return Mood(value: value, text: text);
  }

  @override
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();

    builder.element(
      'mood',
      attributes: <String, String>{'xmlns': 'http://jabber.org/protocol/mood'},
      nest: () {
        if (value?.isNotEmpty ?? false) builder.element(value!);
        if (text?.isNotEmpty ?? false) {
          builder.element('text', nest: () => builder.text(text!));
        }
      },
    );

    return builder.buildDocument().rootElement;
  }

  @override
  String get name => 'mood';

  @override
  String get tag => moodTag;
}
