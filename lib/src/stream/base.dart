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

  if (overrides) {
    for (final interface in plugin.overrides) {
      stanza.pluginOverrides[interface] = plugin.pluginAttribute;
    }
  }
}

class _Multi extends XMLBase {
  // List<XMLBase> getMulti({String? language}) {
  //   final parent = failWithoutParent;
  //   if (language == null || language == '*') {

  //   }
  // }

  XMLBase get failWithoutParent {
    XMLBase? parent;
    if (this.parent != null) {
      parent = this.parent;
    }
    if (parent == null) {
      throw Exception('No stanza parent for multifactory');
    }
    return parent;
  }
}

class XMLBase {
  XMLBase({this.element}) {
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
            final handler = plugin.gettersAndSetters[#getMethod];

            if (handler != null) {
              return noSuchMethod(Invocation.method(#getMethod, [kwargs]));
            }
          }
        }

        if (gettersAndSetters.containsKey(#getMethod)) {
          return noSuchMethod(Invocation.method(#getMethod, [kwargs]));
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

  String getLanguage({String? language}) {
    final result = element!.getAttribute('${Echotils.getNamespace('XML')}lang');
    if (result != null && parent != null) {
      return parent!['lang'] as String;
    }
    return result!;
  }

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
}
