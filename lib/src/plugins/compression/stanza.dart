part of 'compression.dart';

const _$namespace = 'http://jabber.org/features/compress';
const _$protocolNamespace = 'http://jabber.org/protocol/compress';

class CompressionStanza extends XMLBase {
  CompressionStanza({super.getters, super.element, super.parent})
      : super(
          name: 'compression',
          namespace: _$namespace,
          interfaces: <String>{'methods'},
          pluginAttribute: 'compression',
          pluginTagMapping: <String, XMLBase>{},
          pluginAttributeMapping: <String, XMLBase>{},
        ) {
    addGetters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('methods'): (args, base) => methods,
    });
  }

  Set<String> get methods {
    late final methods = <String>{};
    for (final method
        in element!.findAllElements('method', namespace: namespace)) {
      methods.add(method.innerText);
    }

    return methods;
  }

  @override
  CompressionStanza copy({xml.XmlElement? element, XMLBase? parent}) =>
      CompressionStanza(
        getters: getters,
        element: element,
        parent: parent,
      );
}

class Compress extends StanzaBase {
  Compress({super.element, super.parent})
      : super(
          name: 'compress',
          namespace: _$protocolNamespace,
          interfaces: <String>{'method'},
          subInterfaces: <String>{'method'},
          pluginAttribute: 'compress',
          pluginTagMapping: <String, XMLBase>{},
          pluginAttributeMapping: <String, XMLBase>{},
        );

  @override
  Compress copy({
    xml.XmlElement? element,
    XMLBase? parent,
    bool receive = false,
  }) =>
      Compress(
        element: element,
        parent: parent,
      );
}

class Compressed extends StanzaBase {
  Compressed({super.element, super.parent})
      : super(
          name: 'compressed',
          namespace: _$namespace,
          interfaces: <String>{},
          pluginTagMapping: <String, XMLBase>{},
          pluginAttributeMapping: <String, XMLBase>{},
        );

  @override
  Compressed copy({
    xml.XmlElement? element,
    XMLBase? parent,
    bool receive = false,
  }) =>
      Compressed(
        element: element,
        parent: parent,
      );
}
