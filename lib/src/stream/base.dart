import 'package:dartz/dartz.dart';

import 'package:echox/src/echotils/src/echotils.dart';

import 'package:xml/xml.dart' as xml;

typedef FilterCallback = bool Function(dynamic);

dynamic _getAttribute(XMLBase stanza, String attribute) {
  switch (attribute) {
    case 'pluginAttributeMap':
      return stanza.pluginAttributeMap;
    case 'pluginTagMap':
      return stanza.pluginTagMap;
    case 'pluginIterables':
      return stanza.pluginIterables;
    case 'pluginOverrides':
      return stanza.pluginOverrides;
  }
}

void _setAttribute(XMLBase stanza, String attribute, dynamic value) {
  switch (attribute) {
    case 'pluginAttributeMap':
      stanza.pluginAttributeMap = Map<String, XMLBase>.from(value as Map);
      return;
    case 'pluginTagMap':
      stanza.pluginTagMap = Map<String, XMLBase>.from(value as Map);
      return;
    case 'pluginIterables':
      stanza.pluginIterables = value as Set<XMLBase>;
      return;
    case 'pluginOverrides':
      stanza.pluginOverrides = Map<String, String>.from(value as Map);
      return;
  }
}

// void registerStanzaPlugin(
//   XMLBase stanza,
//   XMLBase plugin, {
//   bool iterable = false,
//   bool overrides = false,
// }) {
//   final tag = '${plugin.namespace}${plugin.name}';
//   const pluginInfo = <String>[
//     'pluginAttributeMap',
//     'pluginTagMap',
//     'pluginIterables',
//     'pluginOverrides',
//   ];

//   for (final attribute in pluginInfo) {
//     final info = _getAttribute(stanza, attribute);
//     _setAttribute(stanza, attribute, info);
//   }

//   stanza.pluginAttributeMap[plugin.pluginAttribute] = plugin;
//   stanza.pluginTagMap[tag] = plugin;

//   if (iterable) {
//     stanza.pluginIterables.add(plugin);
//     if (plugin.pluginMultiAttribute) {}
//   }
//   if (overrides) {
//     for (final interface in plugin.overrides) {
//       stanza.pluginOverrides[interface] = plugin.pluginAttribute;
//     }
//   }
// }

// class _Multi extends XMLBase {
//   late Type _multiStanza;

//   @override
//   bool setup([xml.XmlElement? element]) {
//     this.element = xml.XmlElement(xml.XmlName(''));
//     return false;
//   }

//   FilterCallback pluginFilter(List arguments) => (x) => x is XMLBase;

//   FilterCallback pluginLanguageFilter(List arguments, [String? language]) =>
//       (x) => x is XMLBase;

//   @override
//   dynamic noSuchMethod(Invocation invocation, {bool language = false}) {
//     if (!invocation.isMethod || invocation.namedArguments.isNotEmpty) {
//       super.noSuchMethod(invocation);
//     }
//     final arguments = invocation.positionalArguments;
//     if (language) {
//       return pluginFilter();
//     }
//     return pluginFilter(arguments);
//   }

//   XMLBase? _failWithoutParent() {
//     XMLBase? parent;
//     if (this.parent != null) {
//       parent = this.parent;
//     } else {
//       throw Exception('No stanza parent for multifactory');
//     }

//     return parent;
//   }

//   List<XMLBase> get_multi({String? lang}) {
//     final parent = _failWithoutParent();
//     if (parent == null) return [];
//     final res = lang == null || lang == '*'
//         ? parent.where(pluginFilter())
//         : parent.where(plugin_lang_filter(lang));

//     return res.toList();
//   }
// }

// XMLBase multifactory(XMLBase stanza, String pluginAttribute) {
//   final multi = _Multi();

//   multi.isExtension = true;
//   multi.pluginAttribute = pluginAttribute;
//   multi.multiStanza = stanza;
//   multi.interfaces = {pluginAttribute};
//   multi.languageInterfaces = {pluginAttribute};
//   _setAttribute(multi, 'get$pluginAttribute', getMulti);
//   _setAttribute(multi, 'set$pluginAttribute', setMulti);
//   _setAttribute(multi, 'del$pluginAttribute', deleteAttribute);

//   return multi;
// }

class XMLBase {
  XMLBase({
    xml.XmlElement? element,
    Either<WeakReference<XMLBase>, XMLBase>? parent,
  }) {
    name = 'stanza';
    namespace = Echotils.getNamespace('CLIENT');
    if (element != null) {
      this.element = element;
    }

    parenT(parent);

    /// If XML generated, then everything is ready.
    if (setup(element)) {
      return;
    }
  }

  void parenT(Either<WeakReference<XMLBase>, XMLBase>? parent) {
    if (parent != null) {
      parent.fold(
        (reference) => this.parent = reference.target,
        (parent) => this.parent = parent,
      );
    }
  }

  /// The XML tag name of the element, not including any namespace prefixes.
  late final String name;

  /// The XML namespace for the element. Given `<foo xmlns="bar" />`, then
  /// `namespace = "bar"` should be used.
  ///
  /// Defaults namespace in the constructor scope to `jabber:client` since this
  /// is being used in an XMPP library.
  late String namespace;

  /// The set of keys that the stanza provides for accessing and manipulating
  /// the underlying XML object.
  late Set<String> interfaces = <String>{'type', 'to', 'from', 'id', 'payload'};

  late Set<String> languageInterfaces = <String>{};
  late Map<String, XMLBase> pluginAttributeMap = {};
  late Map<String, XMLBase> pluginTagMap = {};
  late Set<XMLBase> pluginIterables = {};
  late Map<Tuple2<String?, String?>, XMLBase> plugins;

  /// In some cases you may wish to override the behaviour of one of the
  /// parent stanza's interfaces. The `overrides` list specifies the interface
  /// name and access method to be overridden. For example, to override setting
  /// the parent's `condition` interface you would use:
  ///
  /// ```dart
  /// overrides = ['condition'];
  /// ```
  ///
  /// Getting and deleting the `condition` interface would not be affected.
  late List<String> overrides = [];
  late Map<String, String> pluginOverrides = {};
  late String pluginAttribute = 'plugin';

  /// If you need to add a new interface to an existing stanza, you can create
  /// a plugin and set `isExtension = true`. Be sure to set the
  /// `pluginAttribute` value to the desired interface name, and that it is the
  /// only interface listed in `interfaces`. Requests for the new interface
  /// from the parent stanza will be passed to the plugin directly.
  late bool isExtension = false;

  /// [XMLBase] subclasses that are intended to be an iterable group of items,
  /// the `pluginMultiAttribute` value defines an interface for the parent
  /// stanza which returns the entire group of matchihng substanzas.
  late String pluginMultiAttribute = '';
  xml.XmlElement? element;
  XMLBase? parent;
  late final iterables = <XMLBase>[];
  late final loadedPlugins = <String>{};

  bool setup([xml.XmlElement? element]) {
    if (element != null && element != this.element) {
      this.element = element;
      return false;
    }

    if (element != null) {
      return false;
    }

    if (this.element != null) {
      return false;
    }

    for (final ename in name.split('/')) {
      final newXML = xml.XmlElement(xml.XmlName('$namespace$ename'));
      if (this.element == null) {
        this.element = newXML;
      } else {
        this.element!.children.add(newXML);
      }
    }

    if (parent != null) {
      if (parent!.element != null) {
        parent!.element!.children.add(parent!.element!);
      }
    }

    return true;
  }

  XMLBase? enable(String attribute, [String? language]) =>
      initPlugin(attribute: attribute, language: language);

  XMLBase? getPlugin(String name, [String? language, bool check = false]) {
    String? languageTemp = language;
    if (language != null) {
      languageTemp = getLanguage();
    }

    if (!pluginAttributeMap.containsKey(name)) {
      return null;
    }

    final pluginClass = pluginAttributeMap[name];

    if (pluginClass!.isExtension) {
      if (plugins.containsKey(Tuple2(name, null))) {
        return plugins[Tuple2(name, null)];
      } else {
        if (check) return null;
        return initPlugin(attribute: name, language: languageTemp);
      }
    } else {
      if (plugins.containsKey(Tuple2(name, languageTemp))) {
        return plugins[Tuple2(name, languageTemp)];
      } else {
        if (check) return null;
        return initPlugin(attribute: name, language: languageTemp);
      }
    }
  }

  XMLBase? initPlugin({
    String? attribute,
    String? language,
    xml.XmlElement? existingXML,
    bool reuse = true,
    XMLBase? element,
  }) {
    String? languageTemp;
    final defaultLanguage = getLanguage();
    if (language == null) {
      languageTemp = defaultLanguage;
    }

    final pluginClass = pluginAttributeMap[attribute];

    if (pluginClass != null &&
        pluginClass.isExtension &&
        plugins.containsKey(Tuple2(attribute, null))) {
      return plugins[Tuple2(attribute, null)];
    }
    if (reuse && plugins.containsKey(Tuple2(attribute, languageTemp))) {
      return plugins[Tuple2(attribute, languageTemp)];
    }

    XMLBase? plugin;

    if (element != null) {
      plugin = element;
    } else {}

    if (plugin!.isExtension) {
      plugins[Tuple2(attribute, null)] = plugin;
    } else {
      if (languageTemp != defaultLanguage) {
        // plugin['lang'] = lang;
      }
      plugins[Tuple2(attribute, languageTemp)] = plugin;
    }

    if (pluginIterables.contains(pluginClass)) {
      iterables.add(plugin);
      if (pluginMultiAttribute.isNotEmpty) {
        initPlugin(attribute: pluginMultiAttribute);
      }
    }

    loadedPlugins.add(attribute!);

    return plugin;
  }

  String? getLanguage([String? language]) {
    final result = element!.getAttribute('${Echotils.getNamespace('XML')}lang');
    if (result == null && element != null) {
      final parent = this.parent;
      if (parent != null) {
        /// TODO: cast the language of the parent as String.
      }
    }

    return result;
  }
}
