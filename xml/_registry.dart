part of 'stanza.dart';

final _createRegistry = <Type, Stanza Function(XmlElement xml)>{
  IQ: (xml) => IQ(xml: xml),
  Query: (xml) => Query(xml: xml),
};

final _parseRegistry = <Type, Stanza Function(ElementModel model)>{
  IQ: (model) =>
      IQ(namespace: model.namespace, xml: model.xml, parent: model.parent),
  Query: (model) =>
      Query(namespace: model.namespace, xml: model.xml, parent: model.parent),
};
