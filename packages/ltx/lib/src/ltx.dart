import 'dart:async';

import 'package:echotils/echotils.dart';
import 'package:error/error.dart';
import 'package:events_emitter/emitters/event_emitter.dart';
import 'package:xml/xml.dart' as xml;
import 'package:xml/xml_events.dart';

part '_error.dart';

class LTXParser extends EventEmitter {
  LTXParser() {
    parser = StreamController<List<xml.XmlNode>>();

    parser.stream.toXmlEvents().normalizeEvents().forEachEvent(
          onStartElement: _onStartElement,
          onText: _onTextElement,
          onEndElement: _onEndElement,
        );
  }

  late final StreamController<List<xml.XmlNode>> parser;

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
      emit('start', element);
    } else if (cursor != root) {
      cursor!.children.add(element);
    }

    cursor = element;
  }

  void _onTextElement(XmlTextEvent event) {
    if (cursor == null) {
      emit('error', XMLMishap(condition: '${event.value} must be a child'));
      return;
    }

    final textElement = Echotils.xmlTextNode(event.value);
    emit('text', textElement);

    cursor!.children.add(textElement);
  }

  void _onEndElement(XmlEndElementEvent event) {
    if (event.qualifiedName != cursor!.qualifiedName) {
      emit(
        'error',
        XMLMishap(condition: '${cursor!.qualifiedName} must be closed'),
      );
      return;
    }

    if (cursor == root) {
      emit('end', root);
      return;
    }

    if (cursor!.parent == null) {
      cursor!.attachParent(root!);
      emit('element', cursor);
      cursor = root;
      return;
    }

    cursor = cursor!.parentElement;
  }

  void write(xml.XmlElement data) {
    parser.add([data]);
  }
}
