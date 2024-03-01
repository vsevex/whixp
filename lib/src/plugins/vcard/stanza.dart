part of 'vcard.dart';

class VCardTempStanza extends XMLBase {
  VCardTempStanza({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.pluginIterables,
    super.pluginMultiAttribute,
    super.element,
    super.parent,
  }) : super(
          name: 'vCard',
          namespace: WhixpUtils.getNamespace('VCARD'),
          pluginAttribute: 'vcard_temp',
          interfaces: <String>{'FN', 'VERSION'},
          subInterfaces: <String>{'FN', 'VERSION'},
        ) {
    registerPlugin(Name());
    registerPlugin(Photo(), iterable: true);
    registerPlugin(Nickname(), iterable: true);
    registerPlugin(UID(), iterable: true);
  }

  @override
  VCardTempStanza copy({xml.XmlElement? element, XMLBase? parent}) =>
      VCardTempStanza(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        pluginIterables: pluginIterables,
        pluginMultiAttribute: pluginMultiAttribute,
        element: element,
        parent: parent,
      );
}

class Name extends XMLBase {
  Name({
    super.getters,
    super.setters,
    super.element,
    super.parent,
  }) : super(
          name: 'N',
          namespace: WhixpUtils.getNamespace('VCARD'),
          includeNamespace: false,
          pluginAttribute: 'N',
          interfaces: <String>{'FAMILY', 'GIVEN', 'MIDDLE', 'PREFIX', 'SUFFIX'},
          subInterfaces: <String>{
            'FAMILY',
            'GIVEN',
            'MIDDLE',
            'PREFIX',
            'SUFFIX',
          },
        ) {
    addGetters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('family'): (args, base) => family,
      const Symbol('given'): (args, base) => given,
      const Symbol('middle'): (args, base) => middle,
      const Symbol('prefix'): (args, base) => prefix,
      const Symbol('suffix'): (args, base) => suffix,
    });
    addSetters(<Symbol,
        void Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('family'): (value, args, base) => setFamily(value as String),
      const Symbol('given'): (value, args, base) => setGiven(value as String),
      const Symbol('middle'): (value, args, base) => setMiddle(value as String),
      const Symbol('prefix'): (value, args, base) => setPrefix(value as String),
      const Symbol('suffix'): (value, args, base) => setSuffix(value as String),
    });
  }

  void _setComponent(String name, dynamic value) {
    late String result;
    if (value is List) {
      result = value.join(',');
    } else if (value is String) {
      result = value;
    }
    if (value != null) {
      setSubText(name, text: result, keep: true);
    } else {
      deleteSub(name);
    }
  }

  dynamic _getComponent(String name) {
    dynamic value = getSubText(name) as String;
    if ((value as String).contains(',')) {
      value = value.split(',').map((v) => v.trim()).toList();
    }
    return value;
  }

  void setFamily(String value) => _setComponent('FAMILY', value);

  dynamic get family => _getComponent('FAMILY');

  void setGiven(String value) => _setComponent('GIVEN', value);

  dynamic get given => _getComponent('GIVEN');

  void setMiddle(String value) => _setComponent('MIDDLE', value);

  dynamic get middle => _getComponent('MIDDLE');

  void setPrefix(String value) => _setComponent('PREFIX', value);

  dynamic get prefix => _getComponent('PREFIX');

  void setSuffix(String value) => _setComponent('SUFFIX', value);

  dynamic get suffix => _getComponent('SUFFIX');

  @override
  Name copy({xml.XmlElement? element, XMLBase? parent}) => Name(
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
      );
}

class Nickname extends XMLBase {
  Nickname({super.getters, super.setters, super.element, super.parent})
      : super(
          name: 'NICKNAME',
          namespace: WhixpUtils.getNamespace('VCARD'),
          includeNamespace: false,
          pluginAttribute: 'NICKNAME',
          pluginMultiAttribute: 'nicknames',
          interfaces: <String>{'NICKNAME'},
          isExtension: true,
        ) {
    addGetters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('nickname'): (args, base) => nickname,
    });
    addSetters(<Symbol,
        void Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('nickname'): (value, args, base) =>
          setNickname(value as String),
    });
  }

  void setNickname(String value) => element!.innerText = [value].join(',');

  List<String> get nickname {
    if (element!.innerText.isNotEmpty) {
      return element!.innerText.split(',');
    }
    return <String>[];
  }

  @override
  Nickname copy({xml.XmlElement? element, XMLBase? parent}) => Nickname(
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
      );
}

class BinVal extends XMLBase {
  BinVal({
    super.getters,
    super.setters,
    super.deleters,
    super.element,
    super.parent,
  }) : super(
          name: 'BINVAL',
          namespace: WhixpUtils.getNamespace('VCARD'),
          includeNamespace: false,
          pluginAttribute: 'BINVAL',
          interfaces: <String>{'BINVAL'},
          isExtension: true,
        ) {
    addGetters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('binval'): (args, base) => binval,
    });
    addSetters(<Symbol,
        void Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('binval'): (value, args, base) => binval = value as String,
    });
    addDeleters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('binval'): (args, base) => deleteBinval(),
    });
  }

  @override
  bool setup([xml.XmlElement? element]) {
    this.element = WhixpUtils.xmlElement('');
    return super.setup(element);
  }

  set binval(String value) {
    deleteBinval();
    element!.innerText = WhixpUtils.unicode(
      WhixpUtils.base64ToArrayBuffer(WhixpUtils.btoa(value)),
    );
    parent!.add(element);
  }

  String get binval {
    final xml = element!.getElement('BINVAL', namespace: namespace);
    if (xml != null) {
      return WhixpUtils.atob(xml.innerText);
    }
    return '';
  }

  void deleteBinval() => parent!.deleteSub('{$namespace}BINVAL');

  @override
  BinVal copy({xml.XmlElement? element, XMLBase? parent}) => BinVal(
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}

class Photo extends XMLBase {
  Photo({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.element,
    super.parent,
  }) : super(
          name: 'PHOTO',
          namespace: WhixpUtils.getNamespace('VCARD'),
          includeNamespace: false,
          pluginAttribute: 'PHOTO',
          pluginMultiAttribute: 'photos',
          interfaces: <String>{'TYPE', 'EXTVAL'},
          subInterfaces: <String>{'TYPE', 'EXTVAL'},
        ) {
    registerPlugin(BinVal());
  }

  @override
  Photo copy({xml.XmlElement? element, XMLBase? parent}) => Photo(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        element: element,
        parent: parent,
      );
}

class UID extends XMLBase {
  UID({super.getters, super.setters, super.element, super.parent})
      : super(
          name: 'UID',
          namespace: WhixpUtils.getNamespace('VCARD'),
          includeNamespace: false,
          pluginAttribute: 'UID',
          pluginMultiAttribute: 'uids',
          interfaces: <String>{'UID'},
          isExtension: true,
        ) {
    addGetters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('id'): (args, base) => uid,
    });
    addSetters(<Symbol,
        void Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('id'): (value, args, base) => uid = value as String,
    });
  }

  set uid(String value) => element!.innerText = value;

  String get uid => element!.innerText;

  @override
  UID copy({xml.XmlElement? element, XMLBase? parent}) => UID(
        getters: getters,
        setters: setters,
        element: element,
        parent: parent,
      );
}
