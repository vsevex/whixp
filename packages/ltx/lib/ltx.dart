import 'dart:async';

import 'package:echotils/echotils.dart';
import 'package:error/error.dart';
import 'package:event/event.dart';
import 'package:xml/xml.dart' as xml;
import 'package:xml/xml_events.dart';

part '_error.dart';

class LTX {}

class LTXEmitter {
  LTXEmitter() {
    parser = StreamController<List<xml.XmlNode>>();

    parser.stream.toXmlEvents().normalizeEvents().forEachEvent(
          onStartElement: _onStartElement,
          onText: _onTextElement,
          onEndElement: _onEndElement,
        );
  }

  late final StreamController<List<xml.XmlNode>> parser;

  final startEvent = Eventius<xml.XmlElement>();
  final textEvent = Eventius<xml.XmlNode>();
  final elementEvent = Eventius<xml.XmlElement>();
  final endEvent = Eventius<xml.XmlElement>();
  final errorEvent = Eventius<Mishap>();

  xml.XmlElement? root;
  xml.XmlElement? cursor;

  void _onStartElement(XmlStartElementEvent event) {
    final attributes = <Map<String, String>>[];

    for (final attr in event.attributes) {
      attributes.add({attr.name: attr.value});
    }

    final element = Echotils.xmlElement(
      event.qualifiedName,
      attributes: attributes,
    );

    if (root == null) {
      root = element;
      startEvent.fire(element);
    } else if (cursor != root) {
      cursor!.children.add(element);
    }

    cursor = element;
  }

  void _onTextElement(XmlTextEvent event) {
    if (cursor == null) {
      errorEvent.fire(XMLMishap(condition: '${event.value} must be a child'));
      return;
    }

    final textElement = Echotils.xmlTextNode(event.value);
    textEvent.fire(textElement);

    cursor!.children.add(textElement);
  }

  void _onEndElement(XmlEndElementEvent event) {
    if (event.qualifiedName != cursor!.qualifiedName) {
      errorEvent.fire(
        XMLMishap(condition: '${cursor!.qualifiedName} must be closed'),
      );
      return;
    }

    if (cursor == root) {
      endEvent.fire(root!);
      return;
    }

    if (cursor!.parent == null) {
      cursor!.attachParent(root!);
      elementEvent.fire(cursor!);
      cursor = root;
      return;
    }

    cursor = cursor!.parentElement;
  }

  void write(xml.XmlElement data) {
    parser.add([data]);
  }
}

xml.XmlElement? parse(xml.XmlElement element) {
  final emitter = LTXEmitter();

  xml.XmlElement? result;
  Mishap? error;

  emitter.startEvent.addListener((element) => result = element);

  emitter.elementEvent.addListener((element) => result!.children.add(element));

  emitter.errorEvent.addListener((err) => error = err);

  emitter.write(element);

  if (error != null) {
    throw error!;
  } else {
    return result;
  }
}
