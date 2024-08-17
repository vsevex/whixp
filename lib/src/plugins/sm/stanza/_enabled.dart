part of '../feature.dart';

// Define SMEnable class extending [Stanza].
class SMEnable extends Stanza {
  // Default constructor
  const SMEnable({this.resume = false});

  // Instance variable to track resume status
  final bool resume;

  // Override the toXML method to generate XML representation of the object
  @override
  xml.XmlElement toXML() {
    // Create a dictionary to hold XML attributes
    final dictionary = HashMap<String, String>();

    dictionary['xmlns'] = _namespace; // Add xmlns attribute.
    dictionary['resume'] = resume.toString(); // Add resume attribute

    // Create the XML element with the 'enable' tag and attributes from the dictionary
    final element = WhixpUtils.xmlElement('enable', attributes: dictionary);

    return element; // Return the constructed XML element
  }

  @override
  String get name => _enable;
}

class SMEnabled extends Stanza {
  /// Initializes a new instance of [SMEnabled].
  SMEnabled();

  /// The value of 'id' attribute.
  String? id;

  /// The value of 'location' attribute.
  String? location;

  /// The value of 'resume' attribute.
  String? resume;

  /// The value of 'max' attribute.
  int? max;

  /// Creates an [SMEnabled] instance from an XML element.
  ///
  /// [node] The XML element representing the [SMEnabled].
  factory SMEnabled.fromXML(xml.XmlElement node) {
    final enabled = SMEnabled();
    for (final attribute in node.attributes) {
      switch (attribute.localName) {
        case 'id':
          enabled.id = attribute.value;
        case 'location':
          enabled.location = attribute.value;
        case 'resume':
          enabled.resume = attribute.value;
        case 'max':
          enabled.max = int.parse(attribute.value);
      }
    }

    return enabled;
  }

  @override
  xml.XmlElement toXML() {
    final dictionary = HashMap<String, dynamic>();
    dictionary['xmlns'] = _namespace;
    if (id != null) dictionary['id'] = id;
    if (location != null) dictionary['location'] = location;
    if (resume != null) dictionary['resume'] = resume;
    if (max != null && max != 0) dictionary['max'] = max;

    return WhixpUtils.xmlElement('enabled', attributes: dictionary);
  }

  @override
  String get name => _enabled;
}
