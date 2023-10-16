import 'package:dartz/dartz.dart';

import 'package:echox/src/echotils/src/echotils.dart';

import 'package:xml/xml.dart' as xml;

typedef FilterCallback = bool Function(dynamic);

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

Either<String, List<String>> fixNamespace(
  String xpath, {
  bool split = false,
  bool propogate = true,
  String def = '',
}) {
  final fixed = <String>[];
  final namespaceBlocks = xpath.split('{');
  late List<String?> elements;
  late String? namespace;

  for (final block in namespaceBlocks) {
    if (block.contains('}')) {
      final split = block.split('}');
      namespace = split[0];
      elements = split[1].split('/');
    } else {
      namespace = def;
      elements = block.split('/');
    }

    for (final element in elements) {
      if (element != null && element.isNotEmpty) {
        late String tag;
        if (propogate && element[0] != '*') {
          tag = '$namespace$element';
        } else {
          tag = element;
        }
        fixed.add(tag);
      }
    }
  }

  if (split) return right(fixed);
  return left(fixed.join());
}

class XMLBase {
  XMLBase({
    xml.XmlElement? element,
    WeakReference<XMLBase>? parent,
  }) {
    _index = 0;
    name = 'stanza';
    namespace = Echotils.getNamespace('CLIENT');
    pluginAttribute = 'plugin';
    pluginMultiAttribute = '';
    interfaces = <String>{'type', 'to', 'from', 'id', 'payload'};
    subInterfaces = <String>{};
    boolInterfaces = <String>{};
    overrides = <String>[];
    isExtension = false;
    pluginOverrides = <String, String>{};
    pluginAttributeMap = <String, XMLBase>{};
    pluginTagMapping = <String, XMLBase>{};
    iterables = <XMLBase>[];

    if (element != null) {
      this.element = element;
    }

    if (parent != null) {
      this.parent = parent.target;
    }

    /// If XML generated, then everything is ready.
    if (setup(element)) {
      return;
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

  late String pluginAttribute;

  /// [XMLBase] subclasses that are intended to be an iterable group of items,
  /// the `pluginMultiAttribute` value defines an interface for the parent
  /// stanza which returns the entire group of matchihng substanzas.
  late String pluginMultiAttribute;

  /// The set of keys that the stanza provides for accessing and manipulating
  /// the underlying XML object.
  late Set<String> interfaces;

  /// A subset of `interfaces` which maps interfaces to direct subelements of
  /// the underlying XML object. Using this set, the text of these subelements
  /// may be set, retrieved, or removed without needing to define custom
  /// methods.
  late Set<String> subInterfaces;

  /// A subset of `interfaces` which maps the presence of subelements to
  /// boolean values. Using this set allows for quickly checking for the
  /// existence of empty subelements like `<required />`.
  late Set<String> boolInterfaces;
  late Set<String> languageInterfaces = <String>{};

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
  late List<String> overrides;

  /// If you need to add a new interface to an existing stanza, you can create
  /// a plugin and set `isExtension = true`. Be sure to set the
  /// `pluginAttribute` value to the desired interface name, and that it is the
  /// only interface listed in `interfaces`. Requests for the new interface
  /// from the parent stanza will be passed to the plugin directly.
  late bool isExtension;

  late Map<String, String> pluginOverrides;
  late Map<String, XMLBase> pluginAttributeMap;

  /// A mapping of root element tag names (in `$namespaceelementName` format)
  /// to the plugin classes responsible for them.
  late Map<String, XMLBase> pluginTagMapping;

  /// The set of stanza classes that can be iterated over using
  /// the `substanzas` interface.
  late Set<XMLBase> pluginIterables = {};
  late Map<Tuple2<String, String?>, XMLBase> plugins;
  late final loadedPlugins = <String>{};

  /// The underlying [element] for the stanza.
  late xml.XmlElement? element;
  late final List<XMLBase> iterables;
  late int _index;
  late XMLBase? parent;

  bool setup([xml.XmlElement? element]) {
    if (Echotils.getAttr(this, 'element') != null) {
      return false;
    }
    if (Echotils.getAttr(this, 'element') == null && element != null) {
      this.element = element;
      return false;
    }

    for (final ename in name.split('/')) {
      final newXML = xml.XmlElement(xml.XmlName('$namespace$ename'));
      if (Echotils.getAttr(this, 'element') == null) {
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

  void enable() {}

  XMLBase? getPlugin(String name, [String? language, bool check = false]) {
    late final lang = language ?? getLanguage();

    if (pluginAttributeMap.containsKey(name)) {
      return null;
    }

    final pluginClass = pluginAttributeMap[name];

    if (pluginClass != null && pluginClass.isExtension) {
      if (plugins.containsKey(Tuple2(name, null))) {
        return plugins[Tuple2(name, null)];
      } else {
        return check ? null : initPlugin(name, language: language);
      }
    } else {
      if (plugins.containsKey(Tuple2(name, lang))) {
        return plugins[Tuple2(name, lang)];
      } else {
        return check ? null : initPlugin(name, language: language);
      }
    }
  }

  XMLBase? initPlugin(
    String attribute, {
    String? language,
    xml.XmlElement? existingXml,
    bool reuse = true,
    XMLBase? element,
  }) {
    final defaultLanguage = language ?? getLanguage();

    final pluginClass = pluginAttributeMap[attribute];

    if (pluginClass != null &&
        pluginClass.isExtension &&
        plugins.containsKey(Tuple2(attribute, null))) {
      return plugins[Tuple2(attribute, null)];
    }
    if (reuse && plugins.containsKey(tuple2(attribute, language))) {
      return plugins[Tuple2(attribute, language)];
    }

    late XMLBase? plugin;

    if (element != null) {
      plugin = element;
    } else {
      plugin = XMLBase(element: existingXml, parent: WeakReference(this));
    }

    if (plugin.isExtension) {
      plugins[Tuple2(attribute, null)] = plugin;
    } else {
      if (language != defaultLanguage) {
        plugin['lang'] = language;
      }
      plugins[Tuple2(attribute, language)] = plugin;
    }

    if (pluginIterables.contains(plugin)) {
      iterables.add(plugin);
      if (plugin.pluginAttributeMap.isNotEmpty) {
        initPlugin(pluginClass!.pluginMultiAttribute);
      }
    }

    loadedPlugins.add(attribute);

    return plugin;
  }

  void appendXML(xml.XmlElement xml) => element!.children.add(xml);

  bool match(Either<String, List<String>> xpath) {
    Either<String, List<String>> xPath = xpath;
    xPath = xPath.fold((xpath) => _fixNamespace(xpath), (_) => xpath);

    return xPath.fold<bool>((_) => true, (xpath) {
      final components = xpath[0].split('@');
      final tag = components[0];
      final attributes = components.sublist(1);

      if (tag != name &&
          tag != '$namespace$name' &&
          !loadedPlugins.contains(tag) &&
          pluginAttribute.contains(tag)) return false;

      bool matchedSubstanzas = false;

      for (final substanza in iterables) {
        if (xpath.sublist(1) == []) break;
        matchedSubstanzas = substanza.match(right(xpath.sublist(1)));

        if (matchedSubstanzas) break;
      }

      for (final attribute in attributes) {
        final name = attribute.split('=')[0];
        final value = attribute.split('=')[1];

        if (name != value) return false;
      }

      if (xpath.length > 1) {
        final nextTag = xpath[1];
        if (subInterfaces.contains(nextTag) && this[nextTag] != null) {
          return true;
        }

        if (!matchedSubstanzas && xpath.length > 1) {
          final nextTag = xpath[1].split('@')[0].split('}')[-1];
          final languages = <String?>[];
          for (final entry in plugins.entries) {
            final name = entry.key;
            if (name.value1 == nextTag) {
              languages.add(name.value2);
            }
          }

          for (final language in languages) {
            final plugin = getPlugin(nextTag, language);
            if (plugin != null && plugin.match(right(xpath.sublist(1)))) {
              return true;
            }
          }

          return false;
        }
      }

      return true;
    });
  }

  Either<String, List<String>> _fixNamespace(
    String xpath, [
    bool split = false,
    bool propogate = false,
  ]) =>
      fixNamespace(xpath, split: split, propogate: propogate);

  dynamic get(String key, [dynamic def]) {
    final value = this[key];
    if (value == null || value == '') {
      return def;
    }
    return value;
  }

  void clear() {
    for (final child in element!.childElements) {
      child.childElements.toList().remove(child);
    }

    for (final plugin in plugins.keys) {
      plugins.remove(plugin);
    }
  }

  String? getLanguage() {
    final result = element!.getAttribute('${Echotils.getNamespace('XML')}lang');
    if (result == null && parent != null) {
      return parent['lang'];
    }
    return result;
  }

  void setLanguage([String? language]) {
    deleteLanguage();
    final attribute = '${Echotils.getNamespace('XML')}lang';
    if (language != null) {
      element!.setAttribute(attribute, language);
    }
  }

  void deleteLanguage() {
    final attribute = '${Echotils.getNamespace('XML')}lang';
    if (element!.getAttribute(attribute) != null) {
      return element!.removeAttribute(attribute);
    }
  }

  dynamic operator [](String fullAttribute) {
    return fullAttribute;
  }

  void operator []=(int index, String value) {
    
  }

  String get tagname => '$namespace$name';

  String get keys {
    final buffer = StringBuffer();
    for (final x in interfaces) {
      buffer.write(x);
    }
    for (final x in loadedPlugins) {
      buffer.write(x);
    }
    buffer.write('lang');
    if (iterables.isNotEmpty) {
      buffer.write('substanzas');
    }
    return buffer.toString();
  }
}
