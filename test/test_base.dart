import 'package:test/test.dart';

import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// Assigns a namespace to an element and any children that do not have a
/// namespace.
xml.XmlElement? fixNamespaces(xml.XmlElement element, {String? namespace}) {
  final ns = namespace ?? WhixpUtils.getNamespace('CLIENT');

  if (element.name.qualified.startsWith('{')) {
    return null;
  }

  final tag = xml.XmlName('{$ns}${element.name.qualified}');
  final newElement = xml.XmlElement(tag);
  for (final child in element.descendantElements) {
    final newChild = fixNamespaces(child, namespace: ns);
    if (newChild != null) newElement.children.add(newChild);
  }
  return newElement;
}

/// Compare the given [xml.XmlElement]s
bool compare(
  xml.XmlElement element, {
  required List<xml.XmlElement> elements,
}) {
  if (elements.isEmpty) {
    return false;
  }

  if (elements.length > 1) {
    for (final element2 in elements) {
      if (!compare(element, elements: [element2])) {
        return false;
      }
      return true;
    }
  }

  final other = elements[0];

  assertCopyInvariants(element, other);
  assertPrintingInvariants(other);

  return true;
}

xml.XmlElement parseXMLFromString(String xmlToParse) {
  try {
    return xml.XmlDocument.parse(xmlToParse).rootElement;
  } on xml.XmlParserException catch (error) {
    final message = error.message;
    if (message.contains('Failure')) {
      final knownPrefixes = {
        'stream': WhixpUtils.getNamespace('JABBER_STREAM'),
      };

      final prefix = xmlToParse.split('<')[1].split(':')[0];
      String xmlString = xmlToParse;
      if (knownPrefixes.containsKey(prefix)) {
        xmlString =
            '<fixns xmlns:$prefix="${knownPrefixes[prefix]}">$prefix</fixns>';
      }
      return parseXMLFromString(xmlString);
    } else {
      throw Exception('XML data was mal-formed: $xmlToParse');
    }
  }
}

/// Create and compare several stanza objects to a correct XML string.
///
/// If [useValues] is `false`, tests using stanza.values will not be used.
///
/// Some stanzas provide default values for some interfaces, but these defaults
/// can be problematic for testing since they can easily be forgotten when
/// supplying the XML string. A list of interfaces that use defaults may be
/// provided and the generated stanzas will use the default values for those
/// interfaces if needed.
///
/// However, correcting the supplied XML is not possible for interfaces that
/// add or remove XML elements. Only interfaces that map to XML attributes may
/// be set using the defaults parameter. The supplied XML must take into account
/// any extra elements that are included by default.
void check(
  XMLBase stanza,
  dynamic criteria, {
  String method = 'exact',
  bool useValues = true,
}) {
  late xml.XmlElement eksemel;
  if (criteria is! XMLBase) {
    eksemel = parseXMLFromString(criteria as String);
  } else {
    eksemel = criteria.element!;
  }

  final stanza1 = stanza.copy(element: eksemel);

  if (useValues) {
    final values = Map<String, dynamic>.from(stanza.values);
    final stanza2 = stanza1.copy();
    stanza2.values = values;

    // print('stanza: $stanza');
    // print('stanza1: $stanza1');
    // print('stanza2: $stanza2');

    compare(
      eksemel,
      elements: [
        stanza.element!,
        stanza1.element!,
        stanza2.element!,
      ],
    );
    return;
  }

  compare(
    eksemel,
    elements: [
      stanza.element!,
      stanza1.element!,
    ],
  );
}

void assertCopyInvariants(xml.XmlNode element, xml.XmlNode copy) {
  void compare(xml.XmlNode original, xml.XmlNode copy) {
    expect(
      original,
      isNot(same(copy)),
      reason: 'The copied node should not be identical.',
    );
    expect(
      original.nodeType,
      copy.nodeType,
      reason: 'The copied node type should be the same.',
    );
    if (original is xml.XmlName && copy is xml.XmlName) {
      final originalNamed = original as xml.XmlName;
      final copyNamed = copy as xml.XmlName;
      expect(
        originalNamed.qualified,
        copyNamed.qualified,
        reason: 'The copied name should be equal.',
      );
      expect(
        originalNamed.qualified,
        isNot(same(copyNamed.qualified)),
        reason: 'The copied name should not be identical.',
      );
    }
    expect(
      original.attributes.length,
      copy.attributes.length,
      reason: 'The amount of copied attributes should be the same.',
    );
    for (var i = 0; i < original.attributes.length; i++) {
      compare(original.attributes[i], copy.attributes[i]);
    }
    expect(
      original.children.length,
      copy.children.length,
      reason: 'The amount of copied children should be the same.',
    );
    for (var i = 0; i < original.children.length; i++) {
      compare(original.children[i], copy.children[i]);
    }
  }

  compare(element, copy);
}

void assertPrintingInvariants(xml.XmlNode element) {
  void compare(xml.XmlNode source, xml.XmlNode pretty) {
    expect(source.nodeType, pretty.nodeType);
    expect(source.attributes.length, pretty.attributes.length);
    for (var i = 0; i < source.attributes.length; i++) {
      compare(source.attributes[i], pretty.attributes[i]);
    }
    final sourceChildren =
        source.children.where((node) => node is! xml.XmlText).toList();
    final prettyChildren =
        pretty.children.where((node) => node is! xml.XmlText).toList();
    expect(sourceChildren.length, prettyChildren.length);
    for (var i = 0; i < sourceChildren.length; i++) {
      compare(sourceChildren[i], prettyChildren[i]);
    }
    final sourceText = source.children
        .whereType<xml.XmlText>()
        .map((node) => node.innerText.trim())
        .join();
    final prettyText = pretty.children
        .whereType<xml.XmlText>()
        .map((node) => node.innerText.trim())
        .join();
    expect(sourceText, prettyText);
  }

  compare(
    element,
    xml.XmlDocument.parse(element.toXmlString(pretty: true)).rootElement,
  );
}
