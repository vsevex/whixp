import 'package:dartz/dartz.dart';

import 'package:echox/src/echotils/echotils.dart';

import 'package:xml/xml.dart' as xml;

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
    final iterable = _XMLBaseIterable(iterables)..addElement(parent);
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
    final iterable = _XMLBaseIterable(iterables)..addElement(parent);
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

  void addElement(XMLBase element) => _iterables.add(element);
}

class _XMLBaseIterator implements Iterator<XMLBase> {
  final List<XMLBase> _iterables;
  int _index = 0;

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

    /// Default set the `languageInterfaces` [Set] to empty.
    languageInterfaces = <String>{};

    /// By default, [XMLBase] is not extension.
    isExtension = false;

    /// By default, the created stanza is not multifactory instance.
    isMulti = false;

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
  late final String name;
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
  /// the underlaying XML object. Using this set, the text of these subelements
  /// may be set, retrieved, or removed without needing to define custom
  /// methods.
  late Set<String> subInterfaces;

  /// A subset of `interfaces` which maps to the presence of subelements to
  /// boolean values. Using this set allows for quickly checking for the
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

  /// Indicator to indicate if [XMLBase] is marked as multifactory.
  bool isMulti = true;
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
  late final Set<String> loadedPlugins;
  late List<XMLBase> iterables;
  late XMLBase? parent;

  /// The underlying [element] for the stanza.
  xml.XmlElement? element;

  /// Iterable index. By default equals to `0`.
  late int _index;

  /// The stanza's XML contents initializer.
  ///
  /// Will return `true` if XML was generated acording to the stanza's
  /// definition instead of building a stanza object from an existing XML
  /// object.
  bool setup([xml.XmlElement? element]) {
    if (element != null) {
      return false;
    }
    if (element == null && element != null) {
      this.element = element;
      return false;
    }

    xml.XmlElement lastXML = xml.XmlElement(xml.XmlName(''));

    for (final ename in name.split('/')) {
      final newElement = xml.XmlElement(xml.XmlName('{$namespace}$ename'));
      if (this.element == null) {
        this.element = newElement;
      } else {
        lastXML.children.add(newElement);
      }
      lastXML = newElement;
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
    final lang = language ?? getLanguage();

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
    final lang = language ?? getLanguage();

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
      if (lang != getLanguage()) {
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
  Tuple2<String, Map<String, String>> _getSubText(
    String name, {
    String def = '',
    String? language,
  }) {
    print('$name and $language is supplied');
    return const Tuple2('', {});
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
    /// `attribute` values, then assign `kwargs` values respective to the check.
    final kwargs = (languageInterfaces.contains(language) &&
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
                Invocation.method(Symbol(getMethod), [kwargs]),
              );
            }
          }
        }

        if (gettersAndSetters.containsKey(Symbol(getMethod))) {
          return noSuchMethod(Invocation.method(Symbol(getMethod), [kwargs]));
        } else {
          if (subInterfaces.contains(attribute)) {
            return _getSubText(attribute, language: language);
          } else if (boolInterfaces.contains(attribute)) {
            if (element != null) {
              final element = this.element!.getElement('$namespace$attribute');
              return element != null;
            }
          } else {
            return _getAttribute(attribute);
          }
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

  /// Return the value of top level attribuet of the XML object.
  ///
  /// In case the attribute has not been set, a [def] value can be returned
  /// instead. An empty string is returned if not other default is supplied.
  String? _getAttribute(String name, [String def = '']) =>
      element!.getAttribute(name) ?? def;

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
    print('setting $value to $attribute');
    // final fullAttribute = attribute;
    // final attributeLanguage = '$attribute|'.split('|');
    // final attrib = attributeLanguage[0];
    // final lang = attributeLanguage[1];

    // final kwargs = {};

    // if (languageInterfaces.contains(lang) &&
    //     languageInterfaces.contains(attrib)) {
    //   kwargs['lang'] = lang;
    // }

    // if (interfaces.contains(attrib) || attrib == 'lang') {
    //   if (value != null) {
    //     final setMethod = 'set_${attrib.toLowerCase()}';

    //     if (pluginOverrides.isNotEmpty) {
    //       final name = pluginOverrides[setMethod];

    //       if (name != null && name.isNotEmpty) {
    //         final plugin = getPlugin(name, language: lang);

    //         if (plugin != null) {
    //           final handler = plugin.gettersAndSetters[#getMethod];
    //           if (handler != null) {
    //             noSuchMethod(Invocation.method(#setMethod, [value, kwargs]));
    //             return;
    //           }
    //         }
    //       }
    //     }

    //     if (gettersAndSetters.containsKey(#setMethod)) {
    //       noSuchMethod(Invocation.method(#setMethod, [value, kwargs]));
    //     } else {
    //       if (subInterfaces.contains(attrib)) {
    //         if (value is JabberIDTemp) {}
    //       }
    //     }
    //   }
    // }

    return;
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

  /// Returns the namespacedd name of the stanza's root element.
  ///
  /// The format for the tag name is: '{namespace}elementName'.
  String get tagName => '{$namespace}$name';

  String getLanguage({String? language}) {
    final result = element!.getAttribute('${Echotils.getNamespace('XML')}lang');
    if (result != null && parent != null) {
      return parent!['lang'] as String;
    }
    return result!;
  }

  bool get boolean => true;

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

  /// Returns a string serialization of the underlying XML object.
  @override
  String toString() => Echotils.serialize(element) ?? '';
}
