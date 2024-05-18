import 'package:whixp/src/jid/jid.dart';

import 'package:xml/xml.dart';

import 'base.dart';
import 'iq.dart';
import 'query.dart';

part '_registry.dart';

enum StanzaType { get, set, result, error, none }

mixin class BaseElementFactory {
  const BaseElementFactory();

  static Stanza create<E extends Stanza>(XmlElement xml) =>
      _createRegistry[E]!(xml);
  static BaseElement parse(BaseElement element, ElementModel model) =>
      _parseRegistry[element.runtimeType]!(model);
}

abstract class Stanza extends BaseElement implements BaseElementFactory {
  Stanza(super.name, {super.namespace, super.plugins, super.xml, super.parent});

  JabberID? get to {
    final attribute = getAttribute('to');
    if (attribute.isEmpty) return null;

    return JabberID(attribute);
  }

  set to(JabberID? jid) => setAttribute('to', jid?.toString());

  JabberID? get from {
    final attribute = getAttribute('from');
    if (attribute.isEmpty) return null;

    return JabberID(attribute);
  }

  set from(JabberID? jid) => setAttribute('from', jid?.toString());

  StanzaType get type {
    final attribute = getAttribute('type');
    switch (attribute) {
      case 'get':
        return StanzaType.get;
      case 'set':
        return StanzaType.set;
      case 'result':
        return StanzaType.result;
      case 'error':
        return StanzaType.error;
      default:
        return StanzaType.none;
    }
  }

  set type(StanzaType type) => setAttribute('type', type.name);
}

Stanza create<S extends Stanza>(XmlElement xml) =>
    BaseElementFactory.create<S>(xml);

BaseElement parse(BaseElement element, ElementModel model) =>
    BaseElementFactory.parse(element, model);
