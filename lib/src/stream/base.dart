import 'package:dartz/dartz.dart';

import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/jid/jid.dart';
import 'package:echox/src/transport/transport.dart';
import 'package:meta/meta.dart';

import 'package:xml/xml.dart' as xml;
import 'package:xpath_selector_xml_parser/xpath_selector_xml_parser.dart';

part 'stanza.dart';

typedef _GetterOrDeleter = dynamic Function(dynamic args, XMLBase base);

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
    if (block.contains('>') && block.contains('xmlns')) {
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
          tag = '<$element xmlns="$namespace"/>';
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

/// Associates a [stanza] object as a plugin for another stanza.
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
  final tag = '<${plugin.name} xmlns="${plugin.namespace}"/>';

  stanza._pluginAttributeMapping[plugin._pluginAttribute] = plugin;
  stanza._pluginTagMapping[tag] = plugin;

  if (iterable) {
    stanza._pluginIterables.add(plugin);
    if (plugin._pluginMultiAttribute != null &&
        plugin._pluginMultiAttribute.isNotEmpty) {
      final multiplugin = multifactory(plugin, plugin._pluginMultiAttribute);
      registerStanzaPlugin(stanza, multiplugin);
    }
  }
  if (overrides) {
    for (final interface in plugin._overrides) {
      stanza._pluginOverrides[interface] = plugin._pluginAttribute;
    }
  }
}

XMLBase multifactory(XMLBase stanza, String pluginAttribute) {
  final multistanza = _Multi(
    stanza.runtimeType,
    pluginAttribute: pluginAttribute,
    interfaces: {pluginAttribute},
    languageInterfaces: {pluginAttribute},
    isExtension: true,
    setupOverride: (base, [element]) =>
        base.element = xml.XmlElement(xml.XmlName('')),
  );

  multistanza
    ..addGetters({
      Symbol(pluginAttribute): (args, base) =>
          multistanza.getMulti(base, args as String?),
    })
    ..addSetters({
      Symbol(pluginAttribute): (value, args, base) =>
          multistanza.setMulti(base, value as List<dynamic>, args as String?),
    })
    ..addDeleters({
      Symbol(pluginAttribute): (args, base) =>
          multistanza.deleteMulti(base, args as String?),
    });

  return multistanza;
}

typedef _MultiFilter = bool Function(XMLBase);

class _Multi extends XMLBase {
  _Multi(
    this._multistanza, {
    super.pluginAttribute,
    super.interfaces,
    super.languageInterfaces,
    super.isExtension,
    super.setupOverride,
  });
  late final Type _multistanza;

  List<XMLBase> getMulti(XMLBase base, [String? lang]) {
    final parent = failWithoutParent(base);
    final iterable = _XMLBaseIterable(parent);
    final result = lang == null || lang == '*'
        ? iterable.where(pluginFilter())
        : iterable.where(pluginLanguageFilter(lang));

    return result.toList();
  }

  void setMulti(XMLBase base, List<dynamic> value, [String? language]) {
    final parent = failWithoutParent(base);
    _deleters[Symbol(_pluginAttribute)]?.call(language, base);
    for (final sub in value) {
      parent.add(Tuple2(null, sub as XMLBase));
    }
  }

  XMLBase failWithoutParent(XMLBase base) {
    XMLBase? parent;
    if (base.parent != null) {
      parent = base.parent;
    }
    if (parent == null) {
      throw ArgumentError('No stanza parent for multifactory');
    }

    return parent;
  }

  void deleteMulti(XMLBase base, [String? language]) {
    final parent = failWithoutParent(base);
    final iterable = _XMLBaseIterable(parent);
    final result = language == null || language == '*'
        ? iterable.where(pluginFilter()).toList()
        : iterable.where(pluginLanguageFilter(language)).toList();

    if (result.isEmpty) {
      parent._plugins.remove(Tuple2(_pluginAttribute, ''));
      parent._loadedPlugins.remove(_pluginAttribute);

      parent.element!.children.remove(element);
    } else {
      while (result.isNotEmpty) {
        final stanza = result.removeLast();
        parent._iterables.remove(stanza);
        parent.element!.children.remove(stanza.element);
      }
    }
  }

  _MultiFilter pluginFilter() => (x) => x.runtimeType == _multistanza;

  _MultiFilter pluginLanguageFilter(String? language) =>
      (x) => x.runtimeType == _multistanza && x['lang'] == language;
}

class _XMLBaseIterable extends Iterable<XMLBase> {
  _XMLBaseIterable(this.parent);
  final XMLBase parent;

  @override
  Iterator<XMLBase> get iterator => _XMLBaseIterator(parent);
}

class _XMLBaseIterator implements Iterator<XMLBase> {
  final XMLBase parent;

  _XMLBaseIterator(this.parent);

  @override
  XMLBase get current {
    return parent._iterables[parent._index - 1];
  }

  @override
  bool moveNext() {
    if (parent._index >= parent._iterables.length) {
      parent._index = 0;
      return false;
    } else {
      parent._incrementIndex.call();
      return true;
    }
  }
}

class XMLBase {
  XMLBase({
    /// If no `name` is passed, sets the default name of the stanza to `stanza`
    this.name = 'stanza',

    /// If `null`, then default stanza namespace will be used
    String? namespace,
    String? pluginAttribute,
    String? pluginMultiAttribute,
    List<String>? overrides,
    Map<String, XMLBase>? pluginTagMapping,
    Map<String, XMLBase>? pluginAttributeMapping,

    /// Defaults to predefined ones
    Set<String>? interfaces,
    Set<String>? subInterfaces,
    Set<String>? boolInterfaces,
    Set<String>? languageInterfaces,
    Map<String, String>? pluginOverrides,
    Set<XMLBase>? pluginIterables,
    bool isExtension = false,
    bool includeNamespace = true,
    Map<Symbol, _GetterOrDeleter>? getters,
    Map<Symbol, void Function(dynamic value, dynamic args, XMLBase base)>?
        setters,
    Map<Symbol, _GetterOrDeleter>? deleters,
    this.receive = false,
    this.transport,
    this.setupOverride,
    this.element,
    XMLBase? parent,
  }) {
    /// Equal `namespace` to `CLIENT` by default.
    this.namespace = namespace ?? Echotils.getNamespace('CLIENT');

    _pluginAttribute = pluginAttribute ?? 'plugin';
    _pluginMultiAttribute = pluginMultiAttribute;
    _pluginTagMapping = pluginTagMapping ?? <String, XMLBase>{};
    _pluginAttributeMapping = pluginAttributeMapping ?? <String, XMLBase>{};

    /// Set the `interfaces` predefined ones.
    _interfaces = interfaces ?? {'type', 'to', 'from', 'id', 'payload'};

    /// Set `subInterfaces` to empty by default.
    _subInterfaces = subInterfaces ?? <String>{};

    /// Set `boolInterfaces` to empty by default.
    _boolInterfaces = boolInterfaces ?? <String>{};

    /// Default set the `languageInterfaces` [Set] to empty.
    _languageInterfaces = languageInterfaces ?? <String>{};

    /// Initialize and equal to empty [Map].
    _pluginOverrides = pluginOverrides ?? <String, String>{};

    /// Equal to empty [Set] in case of anything.
    _pluginIterables = pluginIterables ?? <XMLBase>{};

    /// By default, [XMLBase] is not extension.
    _isExtension = isExtension;

    _includeNamespace = includeNamespace;

    _overrides = overrides ?? <String>[];

    _iterables = <XMLBase>[];

    _plugins = <Tuple2<String, String>, XMLBase>{};
    _loadedPlugins = <String>{};

    if (getters != null) addGetters(getters);
    if (setters != null) addSetters(setters);
    if (deleters != null) addDeleters(deleters);

    _index = 0;

    tag = _tagName;

    _parent = null;
    if (parent != null) _parent = parent;

    if (_setup(element)) return;

    for (final child in element!.childElements) {
      final tag =
          '<${child.qualifiedName} xmlns="${child.getAttribute('xmlns')}"/>';
      if (_pluginTagMapping.containsKey(tag) &&
          _pluginTagMapping[tag] != null) {
        final pluginClass = _pluginTagMapping[tag];
        _initPlugin(
          pluginClass!._pluginAttribute,
          existingXML: child,
          reuse: false,
        );
      }
    }
  }

  final bool receive;
  late final Transport? transport;

  /// The XML tag name of the element, not including any namespace prefixes.
  final String name;

  /// The XML namespace for the element. Given `<foo xmlns="bar" />`, then
  /// `namespace = "bar"` should be used.
  ///
  /// Defaults namespace in the constructor scope to `jabber:client` since this
  /// is being used in an XMPP library.
  late String namespace;

  late final String _pluginAttribute;

  /// [XMLBase] subclasses that are intended to be an iterable group of items,
  /// the `pluginMultiAttribute` value defines an interface for the parent
  /// stanza which returns the entire group of matching `substanzas`.
  late final String? _pluginMultiAttribute;

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
  late final List<String> _overrides;

  /// A mapping of root element tag names (in `$namespaceElementName` format)
  /// to the plugin classes responsible for them.
  late final Map<String, XMLBase> _pluginTagMapping;

  late final Map<String, XMLBase> _pluginAttributeMapping;

  /// The set of keys that the stanza provides for accessing and manipulating
  /// the underlying XML object. This [Set] may be augmented with the
  /// `pluginAttribute` value of any registered stanza plugins.
  late final Set<String> _interfaces;

  /// A subset of `interfaces` which maps interfaces to direct subelements of
  /// the underlaying XML object. Using this [Set], the text of these
  /// subelements may be set, retrieved, or removed without needing to define
  /// custom methods.
  late final Set<String> _subInterfaces;

  /// A subset of `interfaces` which maps to the presence of subelements to
  /// boolean values. Using this [Set] allows for quickly checking for the
  /// existence of empty subelements.
  late final Set<String> _boolInterfaces;

  /// A subset of `interfaces` which maps to the presence of subelements to
  /// language values.
  late final Set<String> _languageInterfaces;

  /// A [Map] of interface operations to the overriding functions.
  ///
  /// For instance, after overriding the `set` operation for the interface
  /// `body`, `pluginOverrides` would be:
  ///
  /// ```dart
  /// log(pluginOverrides); /// outputs {'set_body': Function()}
  /// ```
  late final Map<String, String> _pluginOverrides;

  /// The set of stanza classes that can be iterated over using the `substanzas`
  /// interface.
  late final Set<XMLBase> _pluginIterables;

  /// If you need to add a new interface to an existing stanza, you can create
  /// a plugin and set `isExtension = true`. Be sure to set the
  /// `pluginAttribute` value to the desired interface name, and that it is the
  /// only interface listed in `interfaces`. Requests for the new interface
  /// from the parent stanza will be passed to the plugin directly.
  late final bool _isExtension;

  /// Indicates that this stanza or stanza plugin should include [namespace].
  /// You need to specify this value in order to add namespace to your stanza,
  /// 'cause Defaults to `false`.
  late final bool _includeNamespace;

  /// The helper [Map] contains all the required `setter` methods when there is
  /// a need to override the current setter method.
  late final Map<Symbol,
          void Function(dynamic value, dynamic args, XMLBase base)> _setters =
      <Symbol, void Function(dynamic value, dynamic args, XMLBase base)>{};

  /// The helper [Map] contains all the required `getter` methods when there is
  /// a need to override the current getter method.
  late final Map<Symbol, _GetterOrDeleter> _getters =
      <Symbol, _GetterOrDeleter>{};

  /// The helper [Map] contains all the required `delete` methods when there is
  /// a need to override the current delete method.
  late final Map<Symbol, _GetterOrDeleter> _deleters =
      <Symbol, _GetterOrDeleter>{};

  /// Overrider for [setup] for method.
  final void Function(XMLBase base, [xml.XmlElement? element])? setupOverride;

  /// The underlying [element] for the stanza.
  xml.XmlElement? element;
  XMLBase? _parent;
  late final List<XMLBase> _iterables;
  late final Set<String> _loadedPlugins;
  late final Map<Tuple2<String, String>, XMLBase> _plugins;

  /// Index to keep for iterables.
  late int _index;

  @internal
  late final String tag;

  /// The stanza's XML contents initializer.
  ///
  /// Will return `true` if XML was generated according to the stanza's
  /// definition instead of building a stanza object from an existing XML
  /// object.
  bool _setup([xml.XmlElement? element]) {
    if (setupOverride != null) {
      setupOverride?.call(this, element);
    }
    if (this.element != null) {
      return false;
    }
    if (this.element == null && element != null) {
      this.element = element;
      return false;
    }

    xml.XmlElement lastXML = xml.XmlElement(xml.XmlName(''));
    int index = 0;
    for (final ename in name.split('/')) {
      final newElement = index == 0 && _includeNamespace
          ? Echotils.xmlElement(ename, namespace: namespace)
          : Echotils.xmlElement(ename);
      if (this.element == null) {
        this.element = newElement;
      } else {
        lastXML.children.add(newElement);
      }
      lastXML = newElement;
      index++;
    }

    if (_parent != null) {
      _parent!.element!.children.add(this.element!);
    }

    return true;
  }

  /// Enables and initializes a stanza plugin.
  XMLBase enable(String attribute, [String? language]) =>
      _initPlugin(attribute, language: language);

  /// Responsible to retrieve a stanza plugin through the passed [name] and
  /// [language].
  ///
  /// If [check] is true, then the method returns null instead of creating the
  /// object.
  XMLBase? _getPlugin(String name, {String? language, bool check = false}) {
    /// If passed `language` is null, then try to retrieve it through built-in
    /// method.
    final lang = language ?? _getLang;

    if (!_pluginAttributeMapping.containsKey(name)) {
      return null;
    }

    final plugin = _pluginAttributeMapping[name];

    if (plugin == null) return null;

    if (plugin._isExtension) {
      if (_plugins[Tuple2(name, '')] != null) {
        return _plugins[Tuple2(name, '')];
      } else {
        return check ? null : _initPlugin(name, language: lang);
      }
    } else {
      if (_plugins[Tuple2(name, lang)] != null) {
        return _plugins[Tuple2(name, lang)];
      } else {
        return check ? null : _initPlugin(name, language: lang);
      }
    }
  }

  /// Responsible to enable and initialize a stanza plugin.
  XMLBase _initPlugin(
    String attribute, {
    String? language,
    xml.XmlElement? existingXML,
    bool reuse = true,
    XMLBase? element,
  }) {
    final defaultLanguage = _getLang;
    final lang = language ?? defaultLanguage;

    late final pluginClass = _pluginAttributeMapping[attribute]!;

    if (pluginClass._isExtension && _plugins[Tuple2(attribute, '')] != null) {
      return _plugins[Tuple2(attribute, '')]!;
    }
    if (reuse && _plugins[Tuple2(attribute, lang)] != null) {
      return _plugins[Tuple2(attribute, lang)]!;
    }

    late XMLBase plugin;

    if (element != null) {
      plugin = element;
    } else {
      // if (existingXML != null) {
      plugin = pluginClass.copy(existingXML, this);
      // } else {
      //   plugin = pluginClass;
      // }
    }

    if (plugin._isExtension) {
      _plugins[Tuple2(attribute, '')] = plugin;
    } else {
      if (lang != defaultLanguage) plugin['lang'] = lang;

      _plugins[Tuple2(attribute, lang)] = plugin;
    }

    if (_pluginIterables
        .where((element) => element == pluginClass)
        .toList()
        .isNotEmpty) {
      _iterables.add(plugin);
      if (pluginClass._pluginMultiAttribute != null) {
        _initPlugin(pluginClass._pluginMultiAttribute);
      }
    }

    /// Assign `attribute` to the list to indicate that this plugin is loaded
    /// already.
    _loadedPlugins.add(attribute);

    return plugin;
  }

  /// Returns the text contents of a sub element.
  ///
  /// In case the element does not exist, or it has not textual content, a [def]
  /// value can be returned instead. An empty string is returned if no other
  /// default is supplied.
  dynamic getSubText(
    String name, {
    String def = '',
    String? language,
  }) {
    final castedName = '/${_fixNs(name).value1!}';
    if (language != null && language == '*') {
      return _getAllSubText(name, def: def);
    }

    final defaultLanguage = _getLang;
    final lang = language ?? defaultLanguage;

    final stanzas = element!.queryXPath(castedName).nodes;

    if (stanzas.isEmpty) return def;

    String? result;
    for (final stanza in stanzas) {
      if (stanza.isElement) {
        final node = stanza.node;
        if ((_lang(node) ?? defaultLanguage) == lang) {
          if (node.innerText.isEmpty) return def;

          result = node.innerText;
          break;
        }
        if (stanza.node.innerText.isNotEmpty) {
          result = stanza.node.innerText;
        }
      }
    }
    if (result != null) return result;

    return def;
  }

  Map<String, String> _getAllSubText(
    String name, {
    String def = '',
    String? language,
  }) {
    final castedName = _fixNs(name).value1!;

    final defaultLanguage = _getLang;
    final results = <String, String>{};
    final stanzas = element!.findAllElements(castedName);
    if (stanzas.isNotEmpty) {
      for (final stanza in stanzas) {
        final stanzaLanguage = _lang(stanza) ?? defaultLanguage;

        if (!(language != null) ||
            language == "*" ||
            language == defaultLanguage) {
          late String text;
          if (stanza.innerText.isEmpty) {
            text = def;
          } else {
            text = stanza.innerText;
          }

          results[stanzaLanguage] = text;
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
    final defaultLanguage = _getLang;
    final lang = language ?? defaultLanguage;

    if ((text == null || text.isEmpty) && !keep) {
      deleteSub(name, language: lang);
      return null;
    }

    final path = _fixNs(name, split: true).value2!;
    final castedName = path.last;

    late xml.XmlNode? parent = element;
    late List<xml.XmlNode> elements = <xml.XmlElement>[];

    List<String> missingPath = <String>[];
    final searchOrder = List<String>.from(path)..removeLast();

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
      elements = element!
          .queryXPath('/${path.join('/')}')
          .nodes
          .map((item) => item.node)
          .toList();
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
      final elanguage = _lang(element) ?? defaultLanguage;
      if ((lang.isEmpty && elanguage == defaultLanguage) || lang == elanguage) {
        element.innerText = text!;
        return element;
      }
    }

    final tempElement = xml.XmlElement(xml.XmlName(castedName));
    tempElement.innerText = text!;

    if (lang.isNotEmpty && lang != defaultLanguage) {
      tempElement.setAttribute('xml:lang', lang);
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
      if (!(language != null) || language == "*" || entry.key == language) {
        setSubText(name, text: entry.value, keep: keep, language: entry.key);
      }
    }
  }

  /// Remove sub elements that match the given [name] or XPath.
  ///
  /// If the element is in a path, then any parent elements that become empty
  /// after deleting the element may also be deleted if requested by setting
  /// [all] to `true`.
  void deleteSub(String name, {bool all = false, String? language}) {
    final path = _fixNs(name, split: true).value2!;
    final originalTarget = path.last;

    final defaultLanguage = _getLang;
    final lang = language ?? defaultLanguage;

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
              final elementLanguage = _lang(element) ?? defaultLanguage;

              if (lang == '*' || elementLanguage == lang) {
                if (parent!.children[level].innerXml
                    .contains(element.toXmlString())) {
                  parent.children[level].innerXml = parent
                      .children[level].innerXml
                      .replaceFirst(element.toXmlString(), '');
                }
                if (parent.children.contains(element)) {
                  parent.children.remove(element);
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

  Tuple2<String?, List<String>?> _fixNs(
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

  /// Return the value of top level attribute of the XML object.
  ///
  /// In case the attribute has not been set, a [def] value can be returned
  /// instead. An empty string is returned if not other default is supplied.
  String? _getAttribute(String name, [String def = '']) {
    if (element == null) return def;
    return element!.getAttribute(name == 'lang' ? 'xml:lang' : name) ?? def;
  }

  /// Set the value of a top level [attribute] of the XML object.
  ///
  /// If the new [value] is null or an empty string, then the attribute will be
  /// removed.
  void setAttribute(
    String attribute, [
    String? value,
  ]) {
    if (value == null || value.isEmpty) {
      return;
    }
    element!.setAttribute(attribute == 'lang' ? 'xml:lang' : attribute, value);
  }

  void _deleteAttribute(String name) {
    if (element == null) return;
    if (element!.getAttribute(name) != null) element!.removeAttribute(name);
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
  /// is in `_boolInterfaces`
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
    final Map<String, String?> args = (_languageInterfaces.contains(language) &&
            _languageInterfaces.contains(attribute))
        ? {'lang': language}
        : {};

    if (attribute == 'substanzas') {
      return _iterables;
    } else if (_interfaces.contains(attribute) || attribute == 'lang') {
      final getMethod = attribute.toLowerCase();

      if (_pluginOverrides.isNotEmpty) {
        final name = _pluginOverrides[getMethod];

        if (name != null && name.isNotEmpty) {
          final plugin = _getPlugin(name, language: language);

          if (plugin != null) {
            final handler = plugin._getters[Symbol(getMethod)];

            if (handler != null) return handler.call(args['lang'], plugin);
          }
        }
      }
      if (_getters.containsKey(Symbol(getMethod))) {
        return _getters[Symbol(getMethod)]?.call(args['lang'], this);
      } else {
        if (_subInterfaces.contains(attribute)) {
          return getSubText(attribute, language: language);
        } else if (_boolInterfaces.contains(attribute)) {
          return element!.getElement(attribute, namespace: namespace) != null;
        } else {
          return _getAttribute(attribute);
        }
      }
    } else if (_pluginAttributeMapping.containsKey(attribute)) {
      final plugin = _getPlugin(attribute, language: language);

      if (plugin != null && plugin._isExtension) {
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
    final args = <String, String?>{};

    if (_languageInterfaces.contains(lang) &&
        _languageInterfaces.contains(attrib)) {
      args['lang'] = lang;
    }

    if (_interfaces.contains(attrib) || attrib == 'lang') {
      if (value != null) {
        final setMethod = attrib.toLowerCase();

        if (_pluginOverrides.isNotEmpty) {
          final name = _pluginOverrides[setMethod];

          if (name != null && name.isNotEmpty) {
            final plugin = _getPlugin(name, language: lang);

            if (plugin != null) {
              final handler = plugin._setters[Symbol(setMethod)];

              if (handler != null) {
                return handler.call(
                  value,
                  args['lang'],
                  plugin,
                );
              }
            }
          }
        }
        if (_setters.containsKey(Symbol(setMethod))) {
          _setters[Symbol(setMethod)]?.call(value, args['lang'], this);
        } else {
          if (_subInterfaces.contains(attrib)) {
            dynamic subvalue;
            if (value is JabberIDTemp) {
              subvalue = value.toString();
            }
            subvalue ??= value;
            if (lang == '*') {
              return _setAllSubText(
                attrib,
                values: subvalue as Map<String, String>,
                language: '*',
              );
            }
            setSubText(attrib, text: subvalue as String?, language: lang);
            return;
          } else if (_boolInterfaces.contains(attrib)) {
            if (value != null && value as bool) {
              setSubText(attrib, text: '', keep: true, language: lang);
              return;
            } else {
              setSubText(attrib, text: '', language: lang);
              return;
            }
          } else {
            return setAttribute(
              attrib,
              (value != null && value is JabberIDTemp)
                  ? value.toString()
                  : value as String?,
            );
          }
        }
      }
    } else if (_pluginAttributeMapping.containsKey(attrib) &&
        _pluginAttributeMapping[attrib] != null) {
      final plugin = _getPlugin(attrib, language: lang);
      if (plugin != null) {
        plugin[fullAttribute] = value;
      }
    }

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
    final lang = attributeLanguage[1].isNotEmpty ? attributeLanguage[1] : null;
    final args = <String, String?>{};

    if (_languageInterfaces.contains(lang) &&
        _languageInterfaces.contains(attrib)) {
      args['lang'] = lang;
    }

    if (_interfaces.contains(attrib) || attrib == 'lang') {
      final deleteMethod = attrib.toLowerCase();

      if (_pluginOverrides.isNotEmpty) {
        final name = _pluginOverrides[deleteMethod];

        if (name != null && name.isNotEmpty) {
          final plugin = _getPlugin(attrib, language: lang);

          if (plugin != null) {
            final handler = plugin._deleters[Symbol(deleteMethod)];

            if (handler != null) {
              handler.call(args['lang'], plugin);
              return;
            }
          }
        }
      }
      if (_deleters.containsKey(Symbol(deleteMethod))) {
        _deleters[Symbol(deleteMethod)]?.call(args['lang'], this);
      } else {
        if (_subInterfaces.contains(attrib)) {
          return deleteSub(attrib, language: lang);
        } else if (_boolInterfaces.contains(attrib)) {
          return deleteSub(attrib, language: lang);
        } else {
          return _deleteAttribute(attrib);
        }
      }
    } else if (_pluginAttributeMapping.containsKey(attrib) &&
        _pluginAttributeMapping[attrib] != null) {
      final plugin = _getPlugin(attrib, language: lang, check: true);
      if (plugin == null) {
        return;
      }
      if (plugin._isExtension) {
        plugin.delete(fullAttribute);
        _plugins.remove(Tuple2(attrib, ''));
      } else {
        _plugins.remove(Tuple2(attrib, plugin['lang']));
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
      if (item.value1!.nodeType == xml.XmlNodeType.ELEMENT) {
        return _addXML(item.value1!);
      } else {
        throw ArgumentError('The provided element is not in type of XmlNode');
      }
    }
    if (item.value2 != null) {
      final base = item.value2!;
      element!.children.add(base.element!);
      if (base == _pluginTagMapping[base._tagName]) {
        _initPlugin(
          base._pluginAttribute,
          existingXML: base.element,
          element: base,
          reuse: false,
        );
      } else if (_pluginIterables.contains(base)) {
        _iterables.add(base);
        if (base._pluginMultiAttribute != null &&
            base._pluginMultiAttribute.isNotEmpty) {
          _initPlugin(base._pluginMultiAttribute);
        }
      } else {
        _iterables.add(base);
      }
    }

    return this;
  }

  XMLBase _addXML(xml.XmlElement element) =>
      this..element!.children.add(element);

  /// Returns the namespaced name of the stanza's root element.
  ///
  /// The format for the tag name is: '{namespace}elementName'.
  String get _tagName => '<$name xmlns="$namespace"/>';

  String? _lang(xml.XmlNode element) {
    final result = element
        .queryXPath(
          "//@*[local-name()='xml:lang' and namespace-uri()='${Echotils.getNamespace('XML')}']",
        )
        .node;

    if (result == null) return null;

    return result.node.getAttribute('xml:lang');
  }

  String get _getLang {
    if (element == null) return '';

    final result = _lang(element!);
    if (result == null && _parent != null) {
      return _parent!['lang'] as String;
    }
    return result ?? '';
  }

  bool get boolean => true;

  Map<Tuple2<String, String>, XMLBase> get plugins => _plugins;

  /// Returns the names of all stanza interfaces provided by the stanza object.
  ///
  /// Allows stanza objects to be used as [Map].
  List<String> get keys {
    final buffer = <String>[];
    for (final x in _interfaces) {
      buffer.add(x);
    }
    for (final x in _loadedPlugins) {
      buffer.add(x);
    }
    buffer.add('lang');
    if (_iterables.isNotEmpty) {
      buffer.add('substanzas');
    }
    return buffer;
  }

  /// Set multiple stanza interface [values] using [Map].
  ///
  /// Stanza plugin values may be set using nested [Map]s.
  set _values(Map<String, dynamic> values) {
    final iterableInterfaces = <String>[
      for (final p in _pluginIterables) p._pluginAttribute,
    ];

    if (values.containsKey('lang')) {
      this['lang'] = values['lang'];
    }

    if (values.containsKey('substanzas')) {
      for (final stanza in _iterables) {
        try {
          element!.children.remove(stanza.element);
        } catch (_) {}
      }
      _iterables.clear();

      final substanzas = values['substanzas'] as List<Map<String, dynamic>>;
      for (final submap in substanzas) {
        if (submap.containsKey('__childtag__')) {
          for (final subclass in _pluginIterables) {
            final childtag =
                '<${subclass.name} xmlns="${subclass.namespace}"/>';
            if (submap['__childtag__'] == childtag) {
              final sub = subclass.copy(null, this);
              sub.values = submap;
              _iterables.add(sub);
            }
          }
        }
      }
    }

    for (final entry in values.entries) {
      final fullInterface = entry.key;
      final interfaceLanguage = '${entry.key}|'.split('|');
      final interface = interfaceLanguage[0];
      final language = interfaceLanguage[1];
      if (interface == 'lang') {
        continue;
      } else if (interface == 'substanzas') {
        continue;
      } else if (_interfaces.contains(interface)) {
        this[fullInterface] = entry.value;
      } else if (_pluginAttributeMapping.containsKey(interface)) {
        if (!iterableInterfaces.contains(interface)) {
          final plugin = _getPlugin(interface, language: language);
          if (plugin != null) {
            plugin.values = entry.value as Map<String, dynamic>;
          }
        }
      }
    }
    return;
  }

  /// Returns a JSON/Map version of the XML content exposed through the stanza's
  /// interfaces.
  Map<String, dynamic> get _values {
    final values = <String, dynamic>{};
    values['lang'] = this['lang'];

    for (final interface in _interfaces) {
      if (this[interface] is JabberIDTemp) {
        values[interface] = (this[interface] as JabberIDTemp).jid;
      } else {
        values[interface] = this[interface];
      }
      if (_languageInterfaces.contains(interface)) {
        values['$interface|*'] = this['$interface|*'];
      }
    }
    for (final plugin in _plugins.entries) {
      final lang = plugin.value['lang'];
      if (lang != null && (lang as String).isNotEmpty) {
        values['${plugin.key.value1}|$lang'] = plugin.value.values;
      } else {
        values[plugin.key.value1] = plugin.value.values;
      }
    }
    if (_iterables.isNotEmpty) {
      final iterables = <Map<String, dynamic>>[];
      for (final stanza in _iterables) {
        iterables.add(stanza.values);
        if (iterables.length - 1 >= 0) {
          iterables[iterables.length - 1]['__childtag__'] = stanza.tag;
        }
      }
      values['substanzas'] = iterables;
    }
    return values;
  }

  /// Remove all XML element contents and plugins.
  void clear() {
    element!.children.clear();

    for (final plugin in _plugins.keys) {
      _plugins.remove(plugin);
    }
  }

  Map<String, dynamic> get values => _values;

  set values(Map<String, dynamic> values) => _values = values;

  /// Getter for an [XMLBase] private in-class variable.
  XMLBase? get parent => _parent;

  /// You need to override this method in order to create a copy from an
  /// existing object due Dart do not have deep copy support for now.
  ///
  /// ### Example:
  /// ```dart
  /// class SimpleStanza extends XMLBase {
  ///   SimpleStanza({super.element, super.parent});
  ///
  ///   @override
  ///   XMLBase copy([xml.XmlElement? element, XMLBase? parent]) =>
  ///     SimpleStanza(element: element, parent: parent);
  /// }
  /// ```
  XMLBase copy([xml.XmlElement? element, XMLBase? parent]) => XMLBase(
        name: name,
        namespace: namespace,
        interfaces: _interfaces,
        pluginAttribute: _pluginAttribute,
        pluginTagMapping: _pluginTagMapping,
        pluginAttributeMapping: _pluginAttributeMapping,
        pluginMultiAttribute: _pluginMultiAttribute,
        overrides: _overrides,
        subInterfaces: _subInterfaces,
        boolInterfaces: _boolInterfaces,
        languageInterfaces: _languageInterfaces,
        pluginIterables: _pluginIterables,
        getters: _getters,
        setters: _setters,
        deleters: _deleters,
        isExtension: _isExtension,
        includeNamespace: _includeNamespace,
        setupOverride: setupOverride,
        element: element,
        parent: parent,
      );

  void addGetters(Map<Symbol, _GetterOrDeleter> getters) =>
      _getters.addAll(getters);

  void addSetters(
    Map<Symbol, void Function(dynamic value, dynamic args, XMLBase base)>
        setters,
  ) =>
      _setters.addAll(setters);

  void addDeleters(Map<Symbol, _GetterOrDeleter> deleters) =>
      _deleters.addAll(deleters);

  void _incrementIndex() => _index++;

  /// Returns a string serialization of the underlying XML object.
  @override
  String toString() => Echotils.serialize(element) ?? '';
}
