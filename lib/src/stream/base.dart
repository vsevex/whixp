import 'package:dartz/dartz.dart';

import 'package:echox/src/echotils/src/echotils.dart';
import 'package:echox/src/jid/jid.dart';

import 'package:xml/xml.dart' as xml;

typedef FilterCallback = bool Function(dynamic);

void registerStanzaPlugin(
  XMLBase stanza,
  XMLBase plugin, {
  bool iterable = false,
  bool overrides = false,
}) {
  final tag = '${plugin.namespace}${plugin.name}';
  const pluginInfo = <String>[
    'pluginAttributeMapping',
    'pluginTagMapping',
    'pluginIterables',
    'pluginOverrides',
  ];

  for (final attribute in pluginInfo) {
    final info = Echotils.getAttr(stanza, attribute);
    Echotils.setAttr(stanza, attribute, info);
  }

  stanza.pluginAttributeMapping[plugin.pluginAttribute] = plugin;
  stanza.pluginTagMapping[tag] = plugin;

  if (iterable) {
    stanza.pluginIterables.add(plugin);
    // if (plugin.pluginMultiAttribute) {}
  }
  if (overrides) {
    for (final interface in plugin.overrides) {
      stanza.pluginOverrides[interface] = plugin.pluginAttribute;
    }
  }
}

Tuple2<String, List<String>> fixNamespace(
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

  if (split) return Tuple2('', fixed);
  return Tuple2(fixed.join(), []);
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
    pluginAttributeMapping = <String, XMLBase>{};
    pluginTagMapping = <String, XMLBase>{};
    iterables = <XMLBase>[];
    gettersAndSetters = {};

    if (element != null) {
      this.element = element;
    }

    this.parent = null;
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
  late Map<String, XMLBase> pluginAttributeMapping;

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

  late Map<Symbol, Function> gettersAndSetters;

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

    if (pluginAttributeMapping.containsKey(name)) {
      return null;
    }

    final pluginClass = pluginAttributeMapping[name];

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

    final pluginClass = pluginAttributeMapping[attribute];

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
      if (plugin.pluginAttributeMapping.isNotEmpty) {
        initPlugin(pluginClass!.pluginMultiAttribute);
      }
    }

    loadedPlugins.add(attribute);

    return plugin;
  }

  Map<String, String> getAllSubtext(
    String name, {
    String def = '',
    String? language,
  }) {
    final castedName = _fixNamespace(name).value1;

    final defaultLanguage = getLanguage();
    final results = <String, String>{};
    final stanzas = element!.findElements(castedName);

    if (stanzas.isNotEmpty) {
      for (final stanza in stanzas) {
        final stanzaLanguage =
            stanza.getAttribute('${Echotils.getNamespace('XML')}lang') ??
                defaultLanguage;
        late String text;
        if (language == null || language == '*' || stanzaLanguage == language) {
          text = def;
        } else {
          text = stanza.innerText;
        }
        results[stanzaLanguage!] = text;
      }
    }

    return results;
  }

  Tuple2<String, Map<String, String>> getSubText(
    String name, {
    String def = '',
    String? language,
  }) {
    final castedName = _fixNamespace(name).value1;
    if (language == '*') {
      return Tuple2('', getAllSubtext(name));
    }

    final defaultLanguage = language ?? getLanguage();
    final stanzas = element!.findElements(castedName);

    if (stanzas.isEmpty) {
      return Tuple2(def, {});
    }

    late String? result;
    for (final stanza in stanzas) {
      if (stanza.getAttribute('${Echotils.getNamespace('XML')}lang') ==
          defaultLanguage) {
        if (stanza.innerText.isEmpty) {
          return Tuple2(def, {});
        }
        result = stanza.innerText;
        break;
      }
      if (stanza.innerText.isNotEmpty) {
        result = stanza.innerText;
      }
    }

    if (result != null && result.isNotEmpty) {
      return Tuple2(result, {});
    }
    return Tuple2(def, {});
  }

  void deleteSub(String name, {bool all = false, String? language}) {
    final path = _fixNamespace(name, true).value2;
    final originalTarget = path.last;

    final defaultLanguage = language ?? getLanguage();
    late xml.XmlElement? parent;

    for (int level = 0; level < path.length; level++) {
      // Generate the path to the target element
      final elementPath = path.sublist(0, path.length - level).join('/');

      // Generate the path to the parent element (if applicable)
      final parentPath =
          level > 0 ? path.sublist(0, path.length - level - 1).join('/') : null;

      final elements = element!.findElements(elementPath);
      if (parentPath != null && parentPath.isNotEmpty) {
        parent = element!.getElement(parentPath);
      }
      for (final element in elements) {
        if (element.name.local == originalTarget ||
            element.children.isNotEmpty) {
          final elementLanguage =
              element.getAttribute('${Echotils.getNamespace('XML')}lang') ??
                  defaultLanguage;
          if (defaultLanguage == '*' || elementLanguage == defaultLanguage) {
            parent!.children.remove(element);
          }
        }
      }

      if (!all) {
        return;
      }
    }
  }

  xml.XmlElement? setSubText(
    String name, {
    String? text,
    bool keep = false,
    String? language,
  }) {
    final defaultLanguage = language ?? getLanguage();

    if (text == null && !keep) {
      deleteSub(name, language: defaultLanguage);
      return null;
    }

    final path = _fixNamespace(name, true).value2;
    final castedName = path.last;
    late xml.XmlElement? parent;
    late List<xml.XmlElement> elements;

    List<String> missingPath = <String>[];
    final searchOrder = path.sublist(0, path.length - 1);

    while (searchOrder.isNotEmpty) {
      parent = element!.getElement(searchOrder.join('/'));
      final ename = searchOrder.removeLast();
      if (parent != null) {
        break;
      } else {
        missingPath.add(ename);
      }
      missingPath = missingPath.reversed.toList();
    }

    if (parent != null) {
      elements = element!.findElements(path.join('/')).toList();
    } else {
      parent = element;
      elements = [];
    }

    for (final ename in missingPath) {
      element = xml.XmlElement(xml.XmlName(ename));
      parent!.children.add(element!);
      parent = element;
    }

    for (final element in elements) {
      final elanguage =
          element.getAttribute('${Echotils.getNamespace('XML')}lang') ??
              defaultLanguage;
      if ((language == null || language.isEmpty) &&
              elanguage == defaultLanguage ||
          language != null && language == elanguage) {
        element.innerText = text!;
        return element;
      }
    }

    element = xml.XmlElement(xml.XmlName(castedName));
    element!.innerText = text!;
    if (language != null &&
        language.isNotEmpty &&
        language != defaultLanguage) {
      element!.setAttribute('${Echotils.getNamespace('XML')}lang', language);
    }
    parent!.children.add(element!);
    return element;
  }

  void setAllSubText(
    String name,
    Map<String, String> values, {
    bool keep = false,
    String? language,
  }) {
    deleteSub(name, language: language);
    for (final value in values.entries) {
      if ((language == null || language.isEmpty) ||
          language == '*' ||
          value.key == language) {
        setSubText(name, text: value.value, keep: keep, language: value.key);
      }
    }
  }

  String getAttribute(String name, [String def = '']) =>
      element!.getAttribute(name) ?? def;

  void setAttribute(String name, [Tuple2<String, JabberIDTemp?>? value]) {
    String? castedValue;
    if (value == null || value.value1.isEmpty) {
      deleteItem(name);
    } else {
      if (value.value2 != null) {
        castedValue = value.value2.toString();
      }
      element!.setAttribute(name, castedValue ?? value.value1);
    }
  }

  void deleteAttribute(String name) {
    if (element!.getAttribute(name) != null) {
      element!.removeAttribute(name);
    }
  }

  void appendXML(xml.XmlElement xml) => element!.children.add(xml);

  bool match(Either<String, List<String>> xpath) {
    late List<String> xPath;
    xPath = xpath.fold<List<String>>(
      (xpath) => _fixNamespace(xpath, true).value2,
      id,
    );

    final components = xPath[0].split('@');
    final tag = components[0];
    final attributes = components.sublist(1);

    if (tag != name &&
        tag != '$namespace$name' &&
        !loadedPlugins.contains(tag) &&
        pluginAttribute.contains(tag)) return false;

    bool matchedSubstanzas = false;

    for (final substanza in iterables) {
      if (xPath.sublist(1) == []) break;
      matchedSubstanzas = substanza.match(right(xPath.sublist(1)));

      if (matchedSubstanzas) break;
    }

    for (final attribute in attributes) {
      final name = attribute.split('=')[0];
      final value = attribute.split('=')[1];

      if (name != value) return false;
    }

    if (xPath.length > 1) {
      final nextTag = xPath[1];
      if (subInterfaces.contains(nextTag) && this[nextTag] != null) {
        return true;
      }

      if (!matchedSubstanzas && xPath.length > 1) {
        final nextTag = xPath[1].split('@')[0].split('}')[-1];
        final languages = <String?>[];
        for (final entry in plugins.entries) {
          final name = entry.key;
          if (name.value1 == nextTag) {
            languages.add(name.value2);
          }
        }

        for (final language in languages) {
          final plugin = getPlugin(nextTag, language);
          if (plugin != null && plugin.match(right(xPath.sublist(1)))) {
            return true;
          }
        }

        return false;
      }
    }

    return true;
  }

  Tuple2<String, List<String>> _fixNamespace(
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
      return parent!['lang'] as String;
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
    final split = '$fullAttribute|'.split('|');
    final attribute = split[0];
    final language = split[1];

    final kwargs =
        (language.isNotEmpty && languageInterfaces.contains(attribute))
            ? {'lang': language}
            : {};

    if (attribute == 'substanzas') {
      return iterables;
    } else if (interfaces.contains(attribute) || attribute == 'lang') {
      final getMethod = 'get_${attribute.toLowerCase()}';

      if (pluginOverrides.isNotEmpty) {
        final name = pluginOverrides[getMethod];
        if (name != null && name.isNotEmpty) {
          final plugin = getPlugin(name, language);
          if (plugin != null) {
            final handler = gettersAndSetters.containsKey(Symbol(getMethod));
            if (handler) {
              return noSuchMethod(
                Invocation.method(Symbol(getMethod), [kwargs]),
              );
            }
          }
        }
      }

      if (gettersAndSetters.containsKey(Symbol(getMethod))) {
        return noSuchMethod(Invocation.method(Symbol(getMethod), [kwargs]));
      } else {
        if (subInterfaces.contains(attribute)) {
          return getSubText(attribute, language: language);
        } else if (boolInterfaces.contains(attribute)) {
          final element = this.element!.getElement('$namespace$attribute');
          return element != null;
        } else {
          return getAttribute(attribute);
        }
      }
    } else if (pluginAttributeMapping.containsKey(attribute)) {
      final plugin = getPlugin(attribute, language);
      if (plugin != null && plugin.isExtension) return plugin[fullAttribute];
      return plugin;
    } else {
      return '';
    }
  }

  void operator []=(String fullAttribute, dynamic value) {
    final attributeLanguage = '$fullAttribute|'.split('|');
    final attribute = attributeLanguage[0];
    final language = attributeLanguage[1];

    final kwargs = <String, String>{};

    if (language.isNotEmpty && languageInterfaces.contains(attribute)) {
      kwargs['lang'] = language;
    }

    if (interfaces.contains(attribute) || attribute == 'lang') {
      final setMethod = 'set_${attribute.toLowerCase()}';

      if (pluginOverrides.isNotEmpty) {
        final name = pluginOverrides[setMethod];
        if (name != null && name.isNotEmpty) {
          final plugin = getPlugin(name, language);
          if (plugin != null) {
            final handler = gettersAndSetters.containsKey(Symbol(setMethod));
            if (handler) {
              noSuchMethod(
                Invocation.method(Symbol(setMethod), [kwargs]),
              );
              return;
            }
          }
        }
      }
      if (gettersAndSetters.containsKey(Symbol(setMethod))) {
        noSuchMethod(Invocation.method(Symbol(setMethod), [kwargs]));
        return;
      } else {
        if (subInterfaces.contains(attribute)) {
          if (value is JabberIDTemp) {
            /// TODO: integrate string rep value set in this field
          }
          if (language == '*') {
            if (value is Map<String, String>) {
              return setAllSubText(name, value, language: '*');
            }
          }
          if (value is String) {
            setSubText(attribute, text: value, language: language);
          }
          return;
        } else if (boolInterfaces.contains(attribute)) {
          if (value != null) {
            setSubText(attribute, text: '', keep: true, language: language);
            return;
          } else {
            setSubText(attribute, text: '', language: language);
            return;
          }
        } else {
          setAttribute(attribute, Tuple2(value as String, null));
        }
      }
    }
  }

  void deleteItem(String fullAttribute) {
    final attributeLanguage = '$fullAttribute|'.split('|');
    final attribute = attributeLanguage[0];
    final language = attributeLanguage[1];

    final kwargs = <String, String>{};

    if (language.isNotEmpty && languageInterfaces.contains(attribute)) {
      kwargs['lang'] = language;
    }

    if (interfaces.contains(attribute) || attribute == 'lang') {
      final deleteMethod = 'del_${attribute.toLowerCase()}';

      if (pluginOverrides.isNotEmpty) {
        final name = pluginOverrides[deleteMethod];
        if (name != null && name.isNotEmpty) {
          final plugin = getPlugin(attribute, language);
          if (plugin != null) {
            final handler = gettersAndSetters.containsKey(Symbol(deleteMethod));
            if (handler) {
              noSuchMethod(
                Invocation.method(Symbol(deleteMethod), [kwargs]),
              );
              return;
            }
          }
        }
      }
      if (gettersAndSetters.containsKey(Symbol(deleteMethod))) {
        noSuchMethod(Invocation.method(Symbol(deleteMethod), [kwargs]));
        return;
      } else {
        if (subInterfaces.contains(attribute)) {
          return deleteSub(attribute, language: language);
        } else if (boolInterfaces.contains(attribute)) {
          return deleteSub(attribute, language: language);
        } else {
          deleteAttribute(attribute);
        }
      }
    } else if (pluginAttributeMapping.containsKey(attribute)) {
      final plugin = getPlugin(attribute, language, true);
      if (plugin == null) {
        return;
      }
      if (plugin.isExtension) {
        plugin.deleteItem(fullAttribute);
        plugins[Tuple2(attribute, null)]!.deleteItem(fullAttribute);
      } else {
        plugins[Tuple2(attribute, plugin['lang'])]!.deleteItem(fullAttribute);
      }
      loadedPlugins.remove(attribute);
      try {
        element!.children.remove(plugin.element);
      } catch (error) {
        /// something happened
      }
    }
    return;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod &&
        gettersAndSetters.containsKey(invocation.memberName)) {
      return Function.apply(
        gettersAndSetters[invocation.memberName]!,
        invocation.positionalArguments,
        invocation.namedArguments,
      );
    }
    return super.noSuchMethod(invocation);
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
