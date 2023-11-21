import 'package:dartz/dartz.dart';

import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/jid/jid.dart';

import 'package:xml/xml.dart' as xml;
import 'package:xpath_selector_xml_parser/xpath_selector_xml_parser.dart';

/// Applies the stanza's namespace to elements in an [xPath] expression.
Tuple2<String?, List<String>?> fixNamespace(
  String xPath, {
  bool split = false,
  bool propogateNamespace = true,
  String defaultNamespace = '',
}) {
  final fixed = <String>[];

  final namespaceBlocks = xPath.split('<');
  for (final block in namespaceBlocks) {
    late String namespace;
    late List<String> elements;
    if (block.contains('xmlns')) {
      final namespaceBlockSplit = block.split('>');
      namespace = namespaceBlockSplit[0];
      elements = namespaceBlockSplit[1].split('/');
    } else {
      namespace = defaultNamespace;
      elements = block.split('/');
    }

    for (final element in elements) {
      late String tag;
      if (element.isNotEmpty) {
        if (propogateNamespace && element[0] != '*') {
          tag = '{$namespace}$element';
        } else {
          tag = element;
        }
        fixed.add(tag);
      }
    }
  }

  if (split) {
    return Tuple2(null, fixed);
  }
  return Tuple2(fixed.join('/'), null);
}

/// Associate a [stanza] object as a plugin for another stanza.
///
/// [plugin] stanzas marked as iterable will be included in the list of
/// substanzas for the parent, using `parent['subsstanzas']`. If the attribute
/// `pluginMultiAttribute` was defined for the plugin, then the substanza set
/// can be filtered to only instances of the plugin class.
///
/// For instance, given a plugin class `Foo` with
/// `pluginMultiAttribute = 'foos'` then:
///   parent['foos']
/// would return a collection of all `Foo` substanzas.
void registerStanzaPlugin(
  XMLBase stanza,
  XMLBase plugin, {
  bool iterable = false,
  bool overrides = false,
}) {
  final tag = '{${plugin.namespace}}${plugin.name}';
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
    if (plugin.pluginMultiAttribute != null &&
        plugin.pluginMultiAttribute!.isNotEmpty) {
      final multiplugin = multifactory(plugin, plugin.pluginMultiAttribute!);
      registerStanzaPlugin(stanza, multiplugin);
    }
  }
  if (overrides) {
    for (final interface in plugin.overrides) {
      stanza.pluginOverrides[interface] = plugin.pluginAttribute;
    }
  }
}

XMLBase multifactory(XMLBase stanza, String pluginAttribute) {
  final multiStanza = _Multi()
    ..isExtension = true
    ..pluginAttribute = pluginAttribute
    .._multistanza = stanza.runtimeType
    ..interfaces = {pluginAttribute}
    ..languageInterfaces = {pluginAttribute};

  multiStanza.gettersAndSetters[Symbol('get_$pluginAttribute')] =
      ([String? lang]) => multiStanza.getMulti(lang);
  multiStanza.gettersAndSetters[Symbol('set_$pluginAttribute')] =
      (Iterable<XMLBase> value, [String? language]) =>
          multiStanza.setMulti(value, language);
  multiStanza.gettersAndSetters[Symbol('del_$pluginAttribute')] =
      ([String? language]) => multiStanza.deleteMulti(language);

  return multiStanza;
}

typedef _MultiFilter = bool Function(XMLBase);

class _Multi extends XMLBase {
  late Type _multistanza;

  @override
  bool setup([xml.XmlElement? element]) {
    this.element = xml.XmlElement(xml.XmlName(''));
    return false;
  }

  List<XMLBase> getMulti([String? lang]) {
    final parent = failWithoutParent;
    final iterable = _XMLBaseIterable(iterables);
    final res = lang == null || lang == '*'
        ? iterable.where(pluginFilter())
        : iterable.where(pluginLanguageFilter(lang));

    return res.toList();
  }

  void setMulti(Iterable<XMLBase> value, [String? language]) {
    final parent = failWithoutParent;
    noSuchMethod(Invocation.method(Symbol('del_$pluginAttribute'), [language]));
    for (final sub in value) {
      parent.add(Tuple2(null, sub));
    }
  }

  XMLBase get failWithoutParent {
    XMLBase? parent;
    if (this.parent != null) {
      parent = this.parent;
    }
    if (parent == null) {
      throw ArgumentError('No stanza parent for multifactory');
    }
    return parent;
  }

  void deleteMulti([String? language]) {
    final parent = failWithoutParent;
    final iterable = _XMLBaseIterable(iterables);
    final res = language == null || language == '*'
        ? iterable.where(pluginFilter())
        : iterable.where(pluginLanguageFilter(language));

    if (res.isEmpty) {
      parent.plugins.remove(Tuple2(pluginAttribute, null));
      parent.loadedPlugins.remove(pluginAttribute);
      try {
        parent.element!.children.remove(element);
      } catch (_) {}
    } else {
      for (final stanza in res.toList()) {
        parent.iterables.remove(stanza);
        parent.element!.children.remove(stanza.element);
      }
    }
  }

  _MultiFilter pluginFilter() => (x) => x.runtimeType == _multistanza;

  _MultiFilter pluginLanguageFilter(String? language) =>
      (x) => x.runtimeType == _multistanza && x['lang'] == language;
}

class _XMLBaseIterable extends Iterable<XMLBase> {
  _XMLBaseIterable(this._iterables);
  late final List<XMLBase> _iterables;

  @override
  Iterator<XMLBase> get iterator => _XMLBaseIterator(_iterables);
}

class _XMLBaseIterator implements Iterator<XMLBase> {
  final List<XMLBase> _iterables;
  final _index = 0;

  _XMLBaseIterator(this._iterables);

  @override
  XMLBase get current {
    if (_index < _iterables.length) {
      return _iterables[_index];
    } else {
      throw Exception('Iteration must be stopped');
    }
  }

  @override
  bool moveNext() {
    current._index++;
    if (current._index > _iterables.length) {
      current._index = 0;
      return false;
    }
    return _index <= _iterables.length;
  }
}

class XMLBase {
  XMLBase({this.element, XMLBase? parent}) {
    /// Set the default name of the stanza to `stanza`.
    name = 'stanza';
    pluginAttribute = 'plugin';
    pluginTagMapping = <String, XMLBase>{};

    /// Set the `interfaces` predefined ones.
    interfaces = {'type', 'to', 'from', 'id', 'payload'};

    /// Equal `namespace` to `CLIENT` by default.
    namespace = Echotils.getNamespace('CLIENT');

    /// Set `subInterfaces` to empty by default.
    subInterfaces = <String>{};

    /// Set `boolInterfaces` to empty by default.
    boolInterfaces = <String>{};

    /// Default set the `languageInterfaces` [Set] to empty.
    languageInterfaces = <String>{};

    /// By default, [XMLBase] is not extension.
    isExtension = false;

    pluginAttributeMapping = <String, XMLBase>{};

    /// Equal to empty [Set] in case of anything.
    pluginIterables = <XMLBase>{};

    /// Initialize and equal to empty [Map].
    pluginOverrides = <String, String>{};
    overrides = <String>[];

    gettersAndSetters = <Symbol, Function>{};

    iterables = <XMLBase>[];

    plugins = <Tuple2<String, String?>, XMLBase>{};
    loadedPlugins = <String>{};

    _index = 0;

    tag = tagName;

    this.parent = null;
    if (parent != null) this.parent = parent;

    if (setup(element)) return;

    for (final child in element!.descendantElements) {
      if (pluginTagMapping.containsKey(child.name.local) &&
          pluginTagMapping[child.name.local] != null) {
        final pluginClass = pluginTagMapping[child.name.local];
        initPlugin(
          pluginClass!.pluginAttribute,
          existingXML: child,
          reuse: false,
        );
      }
    }
  }

  /// The XML tag name of the element, not including any namespace prefixes.
  late String name;
  late String pluginAttribute;

  /// A mapping of root element tag names (in `$namespaceElementName` format)
  /// to the plugin classes responsible for them.
  late Map<String, XMLBase> pluginTagMapping;

  /// The XML namespace for the element. Given `<foo xmlns="bar" />`, then
  /// `namespace = "bar"` should be used.
  ///
  /// Defaults namespace in the constructor scope to `jabber:client` since this
  /// is being used in an XMPP library.
  late String namespace;

  /// [XMLBase] subclasses that are intended to be an iterable group of items,
  /// the `pluginMultiAttribute` value defines an interface for the parent
  /// stanza which returns the entire group of matching `substanzas`.
  String? pluginMultiAttribute;

  /// The set of keys that the stanza provides for accessing and manipulating
  /// the underlying XML object. This [Set] may be augmented with the
  /// `pluginAttribute` value of any registered stanza plugins.
  late Set<String> interfaces;

  /// A subset of `interfaces` which maps interfaces to direct subelements of
  /// the underlaying XML object. Using this [Set], the text of these
  /// subelements may be set, retrieved, or removed without needing to define
  /// custom methods.
  late Set<String> subInterfaces;

  /// A subset of `interfaces` which maps to the presence of subelements to
  /// boolean values. Using this [Set] allows for quickly checking for the
  /// existence of empty subelements.
  late Set<String> boolInterfaces;

  /// A subset of `interfaces` which maps to the presence of subelements to
  /// language values.
  late Set<String> languageInterfaces;

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

  late Map<String, XMLBase> pluginAttributeMapping;

  /// A [Map] of interface operations to the overriding functions.
  ///
  /// For instance, after overriding the `set` operation for the interface
  /// `body`, `pluginOverrides` would be:
  ///
  /// ```dart
  /// log(pluginOverrides); /// outputs {'set_body': Function()}
  /// ```
  late Map<String, String> pluginOverrides;

  /// The set of stanza classes that can be iterated over using the `substanzas`
  /// interface.
  late Set<XMLBase> pluginIterables;

  /// Responsible to keep track of `getter`, `setter` and other relative
  /// methods that needs to be executed when there is a need and will work in
  /// associate of `pluginOverrides` variable.
  late Map<Symbol, Function> gettersAndSetters;
  late Map<Tuple2<String, String?>, XMLBase> plugins;
  late Set<String> loadedPlugins;
  late List<XMLBase> iterables;
  late XMLBase? parent;

  /// The underlying [element] for the stanza.
  xml.XmlElement? element;

  /// Iterable index. By default equals to `0`.
  late int _index;

  late String tag;

  /// The stanza's XML contents initializer.
  ///
  /// Will return `true` if XML was generated according to the stanza's
  /// definition instead of building a stanza object from an existing XML
  /// object.
  bool setup([xml.XmlElement? element]) {
    if (element != null) {
      return false;
    }
    if (this.element == null && element != null) {
      this.element = element;
      return false;
    }

    xml.XmlElement? lastXML;
    int index = 0;
    for (final ename in name.split('/')) {
      final newElement = index == 0
          ? Echotils.xmlElement(ename, namespace: namespace)
          : Echotils.xmlElement(ename);
      if (this.element == null) {
        this.element = newElement;
      } else {
        lastXML!.children.add(newElement);
      }
      lastXML = newElement;
      index++;
    }

    if (parent != null) {
      parent!.element!.children.add(element!);
    }

    return true;
  }

  /// Responsible to retrieve a stanza plugin through the passed [name] and
  /// [language].
  ///
  /// If [check] is true, then the method returns null instead of creating the
  /// object.
  XMLBase? getPlugin(String name, {String? language, bool check = false}) {
    /// If passed `language` is null, then try to retrieve it through built-in
    /// method.
    final lang = language ?? getLang;

    if (!pluginAttributeMapping.containsKey(name)) {
      return null;
    }

    final plugin = pluginAttributeMapping[name];

    if (plugin == null) return null;
    if (plugin.isExtension) {
      if (plugins[Tuple2(name, null)] != null) {
        return plugins[Tuple2(name, null)];
      } else {
        return check ? null : initPlugin(name, language: lang);
      }
    } else {
      if (plugins[Tuple2(name, lang)] != null) {
        return plugins[Tuple2(name, lang)];
      } else {
        return check ? null : initPlugin(name, language: lang);
      }
    }
  }

  /// Responsible to enable and initialize a stanza plugin.
  XMLBase initPlugin(
    String attribute, {
    String? language,
    xml.XmlElement? existingXML,
    bool reuse = true,
    XMLBase? element,
  }) {
    final lang = language ?? getLang;

    late final pluginClass = pluginAttributeMapping[attribute]!;

    if (pluginClass.isExtension && plugins[Tuple2(attribute, null)] != null) {
      return plugins[Tuple2(attribute, null)]!;
    }
    if (reuse && plugins[Tuple2(attribute, lang)] != null) {
      return plugins[Tuple2(attribute, lang)]!;
    }

    late XMLBase plugin;

    if (element != null) {
      plugin = element;
    } else {
      plugin = pluginClass
        ..parent = this
        ..element = existingXML;
    }

    if (plugin.isExtension) {
      plugins[Tuple2(attribute, null)] = plugin;
    } else {
      if (lang != getLang) {
        plugin['lang'] = lang;
      }
      plugins[Tuple2(attribute, language)] = plugin;
    }

    if (pluginIterables.contains(pluginClass)) {
      iterables.add(plugin);
      if (pluginClass.pluginMultiAttribute != null) {
        initPlugin(pluginClass.pluginMultiAttribute!);
      }
    }

    /// Assign `attribute` to the list to indicate that this plugin is loaded
    /// already.
    loadedPlugins.add(attribute);

    return plugin;
  }

  /// Returns the text contents of a sub element.
  ///
  /// In case the element does not exist, or it has not textual content, a [def]
  /// value can be returned instead. An empty string is returned if no other
  /// default is supplied.
  Tuple2<String?, Map<String, String>?> getSubText(
    String name, {
    String def = '',
    String? language,
  }) {
    final castedName = '/${fixNs(name).value1!}';
    if (language != null && language == '*') {
      return Tuple2(null, _getAllSubText(name, def: def));
    }

    final defaultLanguage =
        (language == null || language.isEmpty) ? getLang : null;

    final stanzas = element!.queryXPath(castedName).nodes;

    if (stanzas.isEmpty) {
      return Tuple2(def, null);
    }

    String? result;
    for (final stanza in stanzas) {
      if (stanza.isElement) {
        final node = stanza.node;
        if ((node.getAttribute(
                  '{${Echotils.getNamespace('XML')}}lang',
                ) ??
                defaultLanguage) ==
            language) {
          if (node.innerText.isEmpty) {
            return Tuple2(def, null);
          }
          result = node.innerText;
          break;
        }
        if (stanza.node.innerText.isNotEmpty) {
          result = stanza.node.innerText;
        }
      }
    }
    if (result != null) {
      return Tuple2(result, null);
    }
    return Tuple2(def, null);
  }

  Map<String, String> _getAllSubText(
    String name, {
    String def = '',
    String? language,
  }) {
    final castedName = fixNs(name).value1!;

    final defaultLanguage = getLang;
    final results = <String, String>{};
    final stanzas = element!.findAllElements(castedName);
    if (stanzas.isNotEmpty) {
      for (final stanza in stanzas) {
        final stanzaLanguage =
            stanza.getAttribute('{${Echotils.getNamespace('XML')}}lang') ??
                defaultLanguage;
        if (language == null || language == '*' || stanzaLanguage == language) {
          late String text;
          if (stanza.innerText.isEmpty) {
            text = def;
          } else {
            text = stanza.innerText;
          }
          results[stanzaLanguage!] = text;
        }
      }
    }

    return results;
  }

  /// Sets the [text] contents of a sub element.
  ///
  /// In case the element does not exist, a element will be created, and its
  /// text contents will be set.
  ///
  /// If the [text] is set to an empty string, or null, then the element will be
  /// removed, unless [keep] is set to `true`.
  xml.XmlNode? setSubText(
    String name, {
    String? text,
    bool keep = false,
    String? language,
  }) {
    final lang = language ?? getLang;

    if ((text == null || text.isEmpty) && !keep) {
      deleteSub(name, language: lang);
      return null;
    }

    final path = fixNs(name, split: true).value2!;
    final castedName = path.last;

    late xml.XmlNode? parent = element;
    late List<xml.XmlNode> elements = <xml.XmlElement>[];

    List<String> missingPath = <String>[];
    final searchOrder = path.sublist(0, path.length - 1);

    while (searchOrder.isNotEmpty) {
      parent = element!.queryXPath('/${searchOrder.join('/')}').node?.node;

      final ename = searchOrder.removeLast();
      if (parent != null) {
        break;
      } else {
        missingPath.add(ename);
      }
    }
    missingPath = missingPath.reversed.toList();

    if (parent != null) {
      try {
        elements = element!
            .queryXPath('/${path.join('/')}')
            .nodes
            .map((item) => item.node)
            .toList();
      } catch (_) {
        elements = parent.children;
      }
    } else {
      parent = element;
      elements = [];
    }

    for (final ename in missingPath) {
      final tempElement = xml.XmlElement(xml.XmlName(ename));
      parent!.children.add(tempElement);
      parent = tempElement;
    }

    for (final element in elements) {
      final elanguage =
          element.getAttribute('${Echotils.getNamespace('XML')}lang') ?? lang;
      if ((language == null || language.isEmpty) && elanguage == lang ||
          language != null && language == elanguage) {
        element.innerText = text!;
        return element;
      }
    }

    final tempElement = xml.XmlElement(xml.XmlName(castedName));
    tempElement.innerText = text!;

    if ((language != null && language.isNotEmpty) && language != lang) {
      tempElement.setAttribute('${Echotils.getNamespace('XML')}lang', language);
    }
    parent!.children.add(tempElement);
    return tempElement;
  }

  void _setAllSubText(
    String name, {
    required Map<String, String> values,
    bool keep = false,
    String? language,
  }) {
    deleteSub(name, language: language);
    for (final entry in values.entries) {
      if (language == null || language == '*' || entry.key == language) {
        setSubText(name, text: entry.value, keep: keep, language: entry.value);
      }
    }
  }

  /// Remove sub elements that match the given [name] or XPath.
  ///
  /// If the element is in a path, then any parent elements that become empty
  /// after deleting the element may also be deleted if requested by setting
  /// [all] to `true`.
  void deleteSub(String name, {bool all = false, String? language}) {
    final path = fixNs(name, split: true).value2!;
    final originalTarget = path.last;

    final lang = language ?? getLang;

    Iterable<int> enumerate<T>(List<T> iterable) sync* {
      for (int i = 0; i < iterable.length; i++) {
        yield i;
      }
    }

    late xml.XmlNode? parent = element;
    for (final level in enumerate(path)) {
      final elementPath = path.sublist(0, path.length - level).join('/');
      final parentPath = (level > 0)
          ? path.sublist(0, path.length - level - 1).join('/')
          : null;

      final elements = element!
          .queryXPath('/$elementPath')
          .nodes
          .map((item) => item.node)
          .toList();
      if (parentPath != null && parentPath.isNotEmpty) {
        parent = element!.queryXPath('/$parentPath').node?.node;
      }
      if (elements.isNotEmpty) {
        parent ??= element;
        for (final element in elements) {
          if (element is xml.XmlElement) {
            if (element.name.qualified == originalTarget ||
                element.children.isEmpty) {
              final elementLanguage = element
                  .queryXPath(
                    "//@*[local-name()='lang' and namespace-uri()='${Echotils.getNamespace('XML')}']",
                  )
                  .attr;
              if (lang == '*' || elementLanguage == lang) {
                if (parent!.children[level].innerXml
                    .contains(element.toXmlString())) {
                  parent.children[level].innerXml = parent
                      .children[level].innerXml
                      .replaceFirst(element.toXmlString(), '');
                }
              }
            }
          }
        }
      }
      if (!all) {
        return;
      }
    }
  }

  Tuple2<String?, List<String>?> fixNs(
    String xPath, {
    bool split = false,
    bool propogateNamespace = false,
  }) =>
      fixNamespace(
        xPath,
        split: split,
        propogateNamespace: propogateNamespace,
        defaultNamespace: namespace,
      );

  /// Return the value of top level attribuet of the XML object.
  ///
  /// In case the attribute has not been set, a [def] value can be returned
  /// instead. An empty string is returned if not other default is supplied.
  String? _getAttribute(String name, [String def = '']) =>
      element!.getAttribute(name) ?? def;

  /// Set the value of a top level [attribute] of the XML object.
  ///
  /// If the new [value] is null or an empty string, then the attribute will be
  /// removed.
  void _setAttribute(
    String attribute, {
    String? value,
  }) {
    if (value == null || value.isEmpty) {
      return;
    }
    element!.setAttribute(attribute, value);
  }

  /// Return the value of a stanza interface using operator overload.
  ///
  /// ### Example:
  /// ```dart
  /// final element = XMLBase();
  /// log(element['body']); /// this must print out 'message contents'
  /// ```
  ///
  /// Stanza interfaces are typically mapped directly to the underlying XML
  /// object, but can be overridden by the presence of a `getAttribute` method
  /// (or `get_foo` where the interface is named `foo`, etc).
  ///
  /// The search order for interface value retrieval for an interface named
  /// `foo` is:
  /// * The list of substanzas (`substanzas`)
  /// * The result of calling the `getFood` override handler
  /// * The result of calling `get_foo`
  /// * The result of calling `getFoo`
  /// * The contents of the `foo` subelement, if `foo` is listed in
  /// `subInterfaces`
  /// * True or false depending on the existence of a `foo` subelement and `foo`
  /// is in `boolInterfaces`
  /// * The value of the `foo` attribute of the XML object
  /// * The plugin named `foo`
  /// * An empty string
  ///
  /// The search for an element will go through the passed `fullAttribute`.
  dynamic operator [](String fullAttribute) {
    final split = '$fullAttribute|'.split('|');
    final attribute = split[0];
    final language = split[1];

    /// Check for if `languageInterfaces` contains both `language` and
    /// `attribute` values, then assign `args` values respective to the check.
    final args = (languageInterfaces.contains(language) &&
            languageInterfaces.contains(attribute))
        ? {'lang': language}
        : {};

    if (attribute == 'substanzas') {
      return interfaces;
    } else if (interfaces.contains(attribute) || attribute == 'lang') {
      final getMethod = 'get_${attribute.toLowerCase()}';

      if (pluginOverrides.isNotEmpty) {
        final name = pluginOverrides[getMethod];

        if (name != null && name.isNotEmpty) {
          final plugin = getPlugin(name, language: language);

          if (plugin != null) {
            final handler = plugin.gettersAndSetters[Symbol(getMethod)];

            if (handler != null) {
              return noSuchMethod(
                Invocation.method(Symbol(getMethod), [args]),
              );
            }
          }
        }
      }
      if (gettersAndSetters.containsKey(Symbol(getMethod))) {
        return noSuchMethod(Invocation.method(Symbol(getMethod), [args]));
      } else {
        if (subInterfaces.contains(attribute)) {
          return getSubText(attribute, language: language);
        } else if (boolInterfaces.contains(attribute)) {
          if (element != null) {
            final element = this.element!.getElement('$namespace$attribute');
            return element != null;
          }
        } else {
          return _getAttribute(attribute);
        }
      }
    } else if (pluginAttributeMapping.containsKey(attribute)) {
      final plugin = getPlugin(attribute, language: language);

      if (plugin != null && plugin.isExtension) {
        return plugin[fullAttribute];
      }

      return plugin;
    } else {
      return '';
    }
  }

  /// Set the [value] of a stanza interface using operator overloading through
  /// the passed [attribute] string.
  ///
  /// ### Example:
  /// ```dart
  /// final element = XMLBase();
  /// element['body'] = 'hert!';
  /// log(element['body']); /// must output 'hert!'
  /// ```
  ///
  /// Stanza interfaces are typically mapped directly to the underlying XML
  /// object, but can be overridden by the presence of a `setAttribute` method
  /// (or `set_foo` where the interface is named `foo`, etc.).
  void operator []=(String attribute, dynamic value) {
    final fullAttribute = attribute;
    final attributeLanguage = '$attribute|'.split('|');
    final attrib = attributeLanguage[0];
    final lang = attributeLanguage[1].isEmpty ? null : attributeLanguage[1];

    final args = {};

    if (languageInterfaces.contains(lang) &&
        languageInterfaces.contains(attrib)) {
      args['lang'] = lang;
    }

    if (interfaces.contains(attrib) || attrib == 'lang') {
      if (value != null) {
        final setMethod = 'set_${attrib.toLowerCase()}';

        if (pluginOverrides.isNotEmpty) {
          final name = pluginOverrides[setMethod];

          if (name != null && name.isNotEmpty) {
            final plugin = getPlugin(name, language: lang);

            if (plugin != null) {
              final handler = plugin.gettersAndSetters[Symbol(setMethod)];
              if (handler != null) {
                noSuchMethod(
                  Invocation.method(Symbol(setMethod), [value, args]),
                );
                return;
              }
            }
          }
        }

        if (gettersAndSetters.containsKey(Symbol(setMethod))) {
          noSuchMethod(Invocation.method(Symbol(setMethod), [value, args]));
        } else {
          if (subInterfaces.contains(attrib)) {
            String? subvalue;
            if (value is JabberIDTemp) {
              subvalue = value.toString();
            }
            subvalue ??= value as String?;
            if (lang == '*') {
              return _setAllSubText(
                attribute,
                values: value as Map<String, String>,
                language: '*',
              );
            }
            setSubText(attribute, text: subvalue, language: lang);
            return;
          } else if (boolInterfaces.contains(attrib)) {
            if (value != null) {
              setSubText(attribute, text: '', keep: true, language: lang);
              return;
            } else {
              setSubText(attribute, text: '', language: lang);
              return;
            }
          } else {
            _setAttribute(
              attrib,
              value: (value != null && value is JabberIDTemp)
                  ? value.toString()
                  : value as String?,
            );
          }
        }
      }
    } else if (pluginAttributeMapping.containsKey(attrib) &&
        pluginAttributeMapping[attrib] != null) {}

    return;
  }

  /// Delete the value of a stanza interface.
  ///
  /// Stanza interfaces are typically mapped directly to the underlying XML
  /// object, but can be overridden by the presence of [noSuchMethod] by adding
  /// [Function] with [Symbol] key under [gettersAndSetters] [Map].
  void delete(String attribute) {
    final fullAttribute = attribute;
    final attributeLanguage = '$attribute|'.split('|');
    final attrib = attributeLanguage[0];
    final lang = attributeLanguage[1].isEmpty ? null : attributeLanguage[1];

    final args = {};

    if (languageInterfaces.contains(lang) &&
        languageInterfaces.contains(attrib)) {
      args['lang'] = lang;
    }

    if (interfaces.contains(attrib) || attrib == 'lang') {
      final deleteMethod = 'del_${attrib.toLowerCase()}';

      if (pluginOverrides.isNotEmpty) {
        final name = pluginOverrides[deleteMethod];

        if (name != null && name.isNotEmpty) {
          final plugin = getPlugin(attrib, language: lang);

          if (plugin != null) {
            final handler = plugin.gettersAndSetters[Symbol(deleteMethod)];

            if (handler != null) {
              noSuchMethod(Invocation.method(Symbol(deleteMethod), [args]));
              return;
            }
          }
        }
      }
      if (gettersAndSetters.containsKey(Symbol(deleteMethod))) {
        noSuchMethod(Invocation.method(Symbol(deleteMethod), [args]));
      } else {
        if (subInterfaces.contains(attrib)) {
          return deleteSub(attrib, language: lang);
        } else if (boolInterfaces.contains(attrib)) {
          return deleteSub(attrib, language: lang);
        } else {
          return deleteSub(attrib);
        }
      }
    } else if (pluginAttributeMapping.containsKey(attrib) &&
        pluginAttributeMapping[attrib] != null) {
      final plugin = getPlugin(attrib, language: lang, check: true);
      if (plugin == null) {
        return;
      }
      if (plugin.isExtension) {
        plugin.delete(fullAttribute);
        plugins.remove(Tuple2(attrib, null));
      } else {
        plugins.remove(Tuple2(attrib, plugin['lang']));
      }
      try {
        element!.children.remove(plugin.element);
      } catch (_) {}
    }
  }

  /// Add either an [xml.XmlElement] object or substanza to this stanza object.
  ///
  /// If a substanza object is appended, it will be added to the list of
  /// iterable stanzas.
  ///
  /// Allows stanza objects to be used like lists.
  XMLBase add(Tuple2<xml.XmlElement?, XMLBase?> item) {
    if (item.value1 != null) {
      if (item.value1!.nodeType is xml.XmlNode) {
        return addXML(item.value1!);
      } else {
        throw ArgumentError('The provided element is not in type of XmlNode');
      }
    }
    if (item.value2 != null) {
      final base = item.value2!;
      element!.children.add(base.element!);
      if (base == pluginTagMapping[base.tagName]) {
        initPlugin(
          pluginAttribute,
          existingXML: base.element,
          element: base,
          reuse: false,
        );
      } else if (pluginIterables.contains(base)) {
        iterables.add(base);
        if (base.pluginMultiAttribute != null &&
            base.pluginMultiAttribute!.isNotEmpty) {
          initPlugin(base.pluginMultiAttribute!);
        }
      } else {
        iterables.add(base);
      }
    }

    return this;
  }

  XMLBase addXML(xml.XmlElement element) =>
      this..element!.children.add(element);

  /// Returns the namespaced name of the stanza's root element.
  ///
  /// The format for the tag name is: '{namespace}elementName'.
  String get tagName => '<$name xmlns: $namespace/>';

  String? get getLang {
    final result = element!.queryXPath(
      "//@*[local-name()='lang' and namespace-uri()='${Echotils.getNamespace('XML')}']",
    );
    if (result.nodes.isNotEmpty && parent != null) {
      return parent!['lang'] as String;
    }
    return result.attr;
  }

  bool get boolean => true;

  /// Returns the names of all stanza interfaces provided by the stanza object.
  ///
  /// Allows stanza objects to be used as [Map].
  List<String> get keys {
    final buffer = <String>[];
    for (final x in interfaces) {
      buffer.add(x);
    }
    for (final x in loadedPlugins) {
      buffer.add(x);
    }
    buffer.add('lang');
    if (iterables.isNotEmpty) {
      buffer.add('substanzas');
    }
    return buffer;
  }

  /// Set multiple stanza interface [values] using [Map].
  ///
  /// Stanza plugin values may be set using nested [Map]s.
  set _values(Map<String, dynamic> values) {
    final iterableInterfaces = <String>[
      for (final p in pluginIterables) p.pluginAttribute,
    ];

    if (values.containsKey('lang')) {
      this['lang'] = values['lang'];
    }

    if (values.containsKey('substanzas')) {
      for (final stanza in iterables) {
        try {
          element!.children.remove(stanza.element);
        } catch (_) {}
      }
      iterables = [];

      final substanzas = values['substanzas'] as List<Map<String, dynamic>>;
      for (final submap in substanzas) {
        if (submap.containsKey('__childtag__')) {
          for (final subclass in pluginIterables) {
            final childtag = '{$namespace}$name';
            if (submap['__childtag__'] == childtag) {
              final sub = subclass..parent = this;
              sub.values = submap;
              iterables.add(sub);
            }
          }
        }
      }
    }

    for (final entry in values.entries) {
      final fullInterface = entry.key;
      final interfaceLanguage = '${entry.key}|'.split('|');
      final interface = interfaceLanguage[0];
      final language =
          interfaceLanguage[1].isEmpty ? getLang : interfaceLanguage[1];

      if (interface == 'lang') {
        continue;
      } else if (interface == 'substanzas') {
        continue;
      } else if (interfaces.contains(interface)) {
        this[fullInterface] = entry.value;
      } else if (pluginAttributeMapping.containsKey(interface)) {
        if (!iterableInterfaces.contains(interface)) {
          final plugin = getPlugin(interface, language: language);
          if (plugin != null) {
            plugin.values = entry.value as Map<String, dynamic>;
          }
        }
      }
    }
  }

  /// Returns a JSON/Map version of the XML content exposed through the stanza's
  /// interfaces.
  Map<String, dynamic> get _values {
    final values = <String, dynamic>{};
    values['lang'] = this['lang'];
    for (final interface in interfaces) {
      if (this[interface] is JabberIDTemp) {
        values[interface] = (this[interface] as JabberIDTemp).jid;
      } else {
        values[interface] = this[interface];
      }
      if (languageInterfaces.contains(interface)) {
        values['$interface|*'] = this['$interface|*'];
      }
    }
    for (final plugin in plugins.entries) {
      final lang = plugin.value['lang'];
      if (lang != null) {
        values['${plugin.key.value1}|lang'] = plugin.value.values;
      } else {
        values[plugin.key.value1] = plugin.value.values;
      }
    }
    if (iterables.isNotEmpty) {
      final iterables = <Map<String, dynamic>>[];
      for (final stanza in this.iterables) {
        iterables.add(stanza.values);
        iterables.last['__childtag__'] = stanza.tag;
      }
      values['substanzas'] = iterables;
    }
    return values;
  }

  Map<String, dynamic> get values => _values;

  set values(Map<String, dynamic> values) => _values = values;

  Iterable<XMLBase> toIterable() => _XMLBaseIterable(iterables);

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) {
      return Function.apply(
        gettersAndSetters[invocation.memberName]!,
        invocation.positionalArguments,
        invocation.namedArguments,
      );
    }
    return super.noSuchMethod(invocation);
  }

  /// You need to override this method in order to create a copy from an
  /// existing object due Dart do not have deep copy support for now.
  ///
  /// ### Example:
  /// ```dart
  /// class SimpleStanza extends XMLBase {
  ///   SimpleStanza({super.element, super.parent});
  ///
  ///   @override
  ///   XMLBase copy() =>
  ///     SimpleStanza(element: element, parent: parent);
  /// }
  /// ```
  // XMLBase copy() => XMLBase(element: element, parent: parent);

  /// Returns a string serialization of the underlying XML object.
  @override
  String toString() => Echotils.serialize(element) ?? '';

  /// Compares the stanza object with another to test for equality.
  ///
  /// Stanzas are equal if their interfaces return the same values, and if they
  /// are both instances of [XMLBase].
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    // Check if the runtime types are the same
    if (runtimeType != other.runtimeType) return false;

    return other is XMLBase &&
        () {
          final otherValues = other.values;
          for (final key in other.keys) {
            if (!values.containsKey(key) || values[key] != otherValues[key]) {
              return false;
            }
          }

          for (final key in keys) {
            if (!values.containsKey(key) || otherValues[key] != values[key]) {
              return false;
            }
          }

          return true;
        }();
  }

  @override
  int get hashCode {
    return values.hashCode ^ keys.hashCode;
  }
}
