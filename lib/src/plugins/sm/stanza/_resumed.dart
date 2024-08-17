part of '../feature.dart';

class SMResume extends Stanza {
  // Default constructor
  const SMResume({this.h, this.previd});

  final int? h;
  final String? previd;

  // Override the toXML method to generate XML representation of the object
  @override
  xml.XmlElement toXML() {
    // Create a dictionary to hold XML attributes
    final dictionary = HashMap<String, String>();

    dictionary['xmlns'] = _namespace;
    if (h != null) dictionary['h'] = h.toString();
    if (previd != null) dictionary['previd'] = previd.toString();

    // Create the XML element with the 'resume' tag and attributes from the
    // dictionary
    final element = WhixpUtils.xmlElement('resume', attributes: dictionary);

    return element;
  }

  @override
  String get name => _resume;
}

class SMResumed extends Stanza {
  /// Initializes a new instance of [SMResumed].
  SMResumed({this.previd, this.h});

  /// The value of 'previd' attribute.
  final String? previd;

  /// The value of 'h' attribute.
  final int? h;

  /// Creates an [SMResumed] instance from an XML element.
  ///
  /// [node] The XML element representing the SMResumed.
  factory SMResumed.fromXML(xml.XmlElement node) {
    String? previd;
    int? h;

    for (final attribute in node.attributes) {
      switch (attribute.localName) {
        case 'previd':
          previd = attribute.value;
        case 'h':
          h = int.parse(attribute.value);
      }
    }

    return SMResumed(previd: previd, h: h);
  }

  @override
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();
    final dictionary = <String, String>{};
    dictionary['xmlns'] = _namespace;
    if (h != null) dictionary['h'] = h.toString();
    if (previd != null) dictionary['previd'] = previd!;

    builder.element('resumed', attributes: dictionary);

    return builder.buildDocument().rootElement;
  }

  @override
  String get name => _resumed;
}
