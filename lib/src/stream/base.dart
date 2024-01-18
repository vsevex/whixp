import 'package:dartz/dartz.dart';

import 'package:meta/meta.dart';

import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/transport.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;
import 'package:xpath_selector_xml_parser/xpath_selector_xml_parser.dart';

part 'stanza.dart';

/// Gets two parameter; The first one is usually refers to language of the
/// stanza. The second is for processing over current stanza and keeps [XMLBase]
/// instance.
typedef _GetterOrDeleter = dynamic Function(dynamic args, XMLBase base);

/// Gets three params; The first one is usually refers to language of the
/// current stanza. The second one is the parameter to set. The third one is
/// [XMLBase] and refers to current stanza instance.
typedef _Setter = void Function(dynamic args, dynamic value, XMLBase base);

/// Applies the stanza's namespace to elements in an [xPath] expression.
///
/// [split] indicates if the fixed XPath should be left as a list of element
/// names of element names with namespaces. Defaults to `false`.
///
/// [propogateNamespace] overrides propagating parent element namespaces to
/// child elements. Useful if you wish to simply split an XPath that has
/// non-specified namepsaces, adnd child and parent namespaces are konwn not to
/// always match. Defaults to `true`.
Tuple2<String?, List<String>?> fixNamespace(
  String xPath, {
  bool split = false,
  bool propogateNamespace = true,
  String defaultNamespace = '',
}) {
  final fixed = <String>[];

  final namespaceBlocks = xPath.split('{');
  for (final block in namespaceBlocks) {
    late String namespace;
    late List<String> elements;
    if (block.contains('}')) {
      final namespaceBlockSplit = block.split('}');
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
  /// Indicates if the plugin stanza should be included in the parent stanza's
  /// iterable [substanzas] interface results.
  bool iterable = false,

  /// Indicates if the plugin should be allowed to override the interface
  /// handlers for the parent stanza, based on the plugin's [overrides] field.
  bool overrides = false,
}) {
  final tag = '{${plugin.namespace}}${plugin.name}';

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

/// Returns a [XMLBase] class for handling reoccuring child stanzas.
XMLBase multifactory(XMLBase stanza, String pluginAttribute) {
  final multistanza = _Multi(
    stanza.runtimeType,
    pluginAttribute: pluginAttribute,
    interfaces: {pluginAttribute},
    languageInterfaces: {pluginAttribute},
    isExtension: true,
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

/// Multifactory class. Responsible to create an stanza with provided
/// substanzas.
class _Multi extends XMLBase {
  _Multi(
    this._multistanza, {
    super.getters,
    super.setters,
    super.deleters,
    super.pluginAttribute,
    super.interfaces,
    super.languageInterfaces,
    super.isExtension,
    super.element,
    super.parent,
  });
  late final Type _multistanza;

  List<XMLBase> getMulti(XMLBase base, [String? lang]) {
    final parent = failWithoutParent(base);
    final iterable = _XMLBaseIterable(parent);

    final result = (lang == null || lang.isEmpty) || lang == '*'
        ? iterable.where(pluginFilter())
        : iterable.where(pluginLanguageFilter(lang));

    return result.toList();
  }

  @override
  bool setup([xml.XmlElement? element]) {
    this.element = WhixpUtils.xmlElement('');
    return false;
  }

  void setMulti(XMLBase base, List<dynamic> value, [String? language]) {
    final parent = failWithoutParent(base);
    _deleters[Symbol(pluginAttribute)]?.call(language, base);
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
    final result = (language == null || language.isEmpty) || language == '*'
        ? iterable.where(pluginFilter()).toList()
        : iterable.where(pluginLanguageFilter(language)).toList();

    if (result.isEmpty) {
      parent._plugins.remove(Tuple2(pluginAttribute, ''));
      parent._loadedPlugins.remove(pluginAttribute);

      parent.element!.children.remove(element);
    } else {
      while (result.isNotEmpty) {
        final stanza = result.removeLast();
        parent.iterables.remove(stanza);
        parent.element!.children.remove(stanza.element);
      }
    }
  }

  _MultiFilter pluginFilter() => (x) => x.runtimeType == _multistanza;

  _MultiFilter pluginLanguageFilter(String? language) =>
      (x) => x.runtimeType == _multistanza && x['lang'] == language;

  @override
  _Multi copy({xml.XmlElement? element, XMLBase? parent}) => _Multi(
        _multistanza,
        getters: getters,
        setters: setters,
        deleters: deleters,
        pluginAttribute: pluginAttribute,
        interfaces: interfaces,
        languageInterfaces: languageInterfaces,
        isExtension: isExtension,
        element: element,
        parent: parent,
      );
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
    return parent.iterables[parent._index - 1];
  }

  @override
  bool moveNext() {
    if (parent._index >= parent.iterables.length) {
      parent._index = 0;
      return false;
    } else {
      parent._incrementIndex.call();
      return true;
    }
  }
}

/// ## XMLBase
///
/// Designed for efficient manipulation of XML elements. Provides a set of
/// methods and functionalities to create, modify, and interact with XML
/// structures.
///
/// Serves as a base and flexible XML manipulation tool for this package,
/// designed to simplify the creation, modification, and interaction with
/// XML. It offers a comprehensive set of features for constructing XML
/// elements, managing attributes, handling child elements, and incorporating
/// dynamic plugins to extend functionality.
///
/// [XMLBase] is created to accommodate a wide range of XML manipulation tasks.
/// Whether you are creating simple XML elements or dealing with complex
/// structures, this class provides a versatile foundation.
///
/// The extensibility of [XMLBase] is the key strength. You can integrate and
/// manage plugins, which may include extensions or custom functionality.
///
/// Stanzas are defined by their name, namespace, and interfaces. For example,
/// a simplistic Message stanza could be defined as:
/// ```dart
/// class Message extends XMLBase {
///   Message()
///       : super(
///           name: 'message',
///           interfaces: {'to', 'from', 'type', 'body'},
///           subInterfaces: {'body'},
///         );
/// }
/// ```
///
/// The resulting Message stanza's content may be accessed as so:
/// ```dart
/// message['to'] = 'vsevex@example.com';
/// message['body'] = 'salam';
/// log(message['body']); /// outputs 'salam'
/// message.delete('body');
/// log(message['body']); /// will output empty string
/// ```
///
/// ### Example:
/// ```dart
/// class TestStanza extends XMLBase {
///   TestStanza({
///     super.name,
///     super.namespace,
///     super.pluginAttribute,
///     super.pluginMultiAttribute,
///     super.overrides,
///     super.interfaces,
///     super.subInterfaces,
///   });
/// }
///
/// void main() {
///   final stanza = TestStanza({name: 'stanza'});
///   /// ...do whatever manipulation you want
///   stanza['test'] = 'salam';
///   /// will add a 'test' child and assign 'salam' text to it
/// }
/// ```
///
/// Extending stanzas through the use of plugins (simple stanza that has
/// pluginAttribute value) is like the following:
/// ```dart
/// class MessagePlugin extends XMLBase {
///   MessagePlugin()
///       : super(
///           name: 'message',
///           interfaces: {'cart', 'hert'},
///           pluginAttribute: 'custom',
///         );
/// }
/// ```
///
/// The plugin stanza class myst be associated with its intended container
/// stanza by using [registerStanzaPlugin] method:
/// ```dart
/// final plugin = MessagePlugin();
/// message.registerPlugin(plugin);
/// ```
///
/// The plugin may then be accessed as if it were built-in to the parent stanza:
/// ```dart
/// message['custom']['cart'] = 'test';
/// ```
class XMLBase {
  /// ## XMLBase
  ///
  /// Default constructor for creating an empty XML element.
  ///
  /// [XMLBase] is designed with customization in mind. Users can extend the
  /// class and override methods, allowing for the manipulation of custom fields
  /// and the implementation of specialized behavior when needed.
  XMLBase({
    /// If no `name` is passed, sets the default name of the stanza to `stanza`
    this.name = 'stanza',

    /// If `null`, then default stanza namespace will be used
    String? namespace,
    this.transport,
    this.pluginAttribute = 'plugin',
    this.pluginMultiAttribute,
    this.overrides = const <String>[],
    Map<String, XMLBase>? pluginTagMapping,
    Map<String, XMLBase>? pluginAttributeMapping,

    /// Defaults to predefined ones
    this.interfaces = const <String>{'type', 'to', 'from', 'id', 'payload'},
    this.subInterfaces = const <String>{},
    this.boolInterfaces = const <String>{},
    this.languageInterfaces = const <String>{},
    Map<String, String>? pluginOverrides,
    Set<XMLBase>? pluginIterables,
    this.receive = false,
    this.isExtension = false,
    this.includeNamespace = true,
    Map<Symbol, _GetterOrDeleter>? getters,
    Map<Symbol, _Setter>? setters,
    Map<Symbol, _GetterOrDeleter>? deleters,
    this.element,
    this.parent,
  }) {
    this.pluginTagMapping = pluginTagMapping ?? <String, XMLBase>{};
    this.pluginAttributeMapping = pluginAttributeMapping ?? <String, XMLBase>{};
    this.pluginOverrides = pluginOverrides ?? <String, String>{};
    this.pluginIterables = pluginIterables ?? <XMLBase>{};

    /// Defaults to `CLIENT`.
    this.namespace = namespace ?? WhixpUtils.getNamespace('CLIENT');

    /// Equal tag to the tag name.
    tag = _tagName;

    if (getters != null) addGetters(getters);
    if (setters != null) addSetters(setters);
    if (deleters != null) addDeleters(deleters);

    if (setup(element)) return;
    final children = <Tuple2<xml.XmlElement, XMLBase?>>{};

    for (final child in element!.childElements.toSet()) {
      final namespace =
          child.getAttribute('xmlns') ?? element!.getAttribute('xmlns');
      final tag = '{$namespace}${child.localName}';

      if (this.pluginTagMapping.containsKey(tag) &&
          this.pluginTagMapping[tag] != null) {
        final pluginClass = this.pluginTagMapping[tag];
        children.add(Tuple2(child, pluginClass));
      }
    }

    /// Growable iterable fix
    for (final child in children) {
      _initPlugin(
        child.value2!.pluginAttribute,
        existingXML: child.value1,
        reuse: false,
      );
    }
  }

  /// Index to keep for iterables.
  int _index = 0;

  /// The XML tag name of the element, not including any namespace prefixes.
  final String name;

  /// The XML namespace for the element. Given `<foo xmlns="bar" />`, then
  /// `namespace = "bar"` should be used.
  ///
  /// Defaults namespace in the constructor scope to `jabber:client` since this
  /// is being used in an XMPP library.
  late String namespace;

  /// Unique identifiers of plugins across [XMLBase] classes.
  final String pluginAttribute;

  /// [XMLBase] subclasses that are intended to be an iterable group of items,
  /// the `pluginMultiAttribute` value defines an interface for the parent
  /// stanza which returns the entire group of matching `substanzas`.
  final String? pluginMultiAttribute;

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
  final List<String> overrides;

  /// A mapping of root element tag names
  /// (in `<$name xmlns="$namespace"/>` format) to the plugin classes
  /// responsible for them.
  late final Map<String, XMLBase> pluginTagMapping;

  /// When there is a need to indicate initialize plugin or get plugin we will
  /// use [pluginAttributeMapping] keeper for this.
  late final Map<String, XMLBase> pluginAttributeMapping;

  /// The set of keys that the stanza provides for accessing and manipulating
  /// the underlying XML object. This [Set] may be augmented with the
  /// [pluginAttribute] value of any registered stanza plugins.
  final Set<String> interfaces;

  /// A subset of `interfaces` which maps interfaces to direct subelements of
  /// the underlaying XML object. Using this [Set], the text of these
  /// subelements may be set, retrieved, or removed without needing to define
  /// custom methods.
  final Set<String> subInterfaces;

  /// A subset of [interfaces] which maps to the presence of subelements to
  /// boolean values. Using this [Set] allows for quickly checking for the
  /// existence of empty subelements.
  final Set<String> boolInterfaces;

  /// A subset of [interfaces] which maps to the presence of subelements to
  /// language values.
  final Set<String> languageInterfaces;

  /// A [Map] of interface operations to the overriding functions.
  ///
  /// For instance, after overriding the `set` operation for the interface
  /// `body`, [pluginOverrides] would be:
  ///
  /// ```dart
  /// log(pluginOverrides); /// outputs {'body': Function()}
  /// ```
  late final Map<String, String> pluginOverrides;

  /// The set of stanza classes that can be iterated over using the `substanzas`
  /// interface.
  late final Set<XMLBase> pluginIterables;

  /// Declares if stanza is incoming or outgoing stanza. Defaults to false.
  final bool receive;

  /// If you need to add a new interface to an existing stanza, you can create
  /// a plugin and set `isExtension = true`. Be sure to set the
  /// [pluginAttribute] value to the desired interface name, and that it is the
  /// only interface listed in [interfaces]. Requests for the new interface
  /// from the parent stanza will be passed to the plugin directly.
  final bool isExtension;

  /// Indicates that this stanza or stanza plugin should include [namespace].
  /// You need to specify this value in order to add namespace to your stanza,
  /// 'cause defaults to `false`.
  final bool includeNamespace;

  /// The helper [Map] contains all the required `setter` methods when there is
  /// a need to override the current setter method.
  late final Map<Symbol, _Setter> _setters = <Symbol, _Setter>{};

  /// The helper [Map] contains all the required `getter` methods when there is
  /// a need to override the current getter method.
  late final Map<Symbol, _GetterOrDeleter> _getters =
      <Symbol, _GetterOrDeleter>{};

  /// The helper [Map] contains all the required `delete` methods when there is
  /// a need to override the current delete method.
  late final Map<Symbol, _GetterOrDeleter> _deleters =
      <Symbol, _GetterOrDeleter>{};

  final iterables = <XMLBase>[];

  /// Keeps all initialized plugins across stanza.
  final _plugins = <Tuple2<String, String>, XMLBase>{};

  /// Keeps all loaded plugins across stanza.
  final _loadedPlugins = <String>{};

  /// The underlying [element] for the stanza.
  xml.XmlElement? element;

  /// The parent [XMLBase] element for the stanza.
  final XMLBase? parent;

  /// Underlying [Transport] for this stanza class. Helps to interact with
  /// socket.
  @internal
  late Transport? transport;

  /// Tag name for the stanza in the format of "<$name xmlns="$namespace"/>".
  @internal
  late final String tag;

  /// The stanza's XML contents initializer.
  ///
  /// Will return `true` if XML was generated according to the stanza's
  /// definition instead of building a stanza object from an existing XML
  /// object.
  bool setup([xml.XmlElement? element]) {
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
      final newElement = index == 0 && includeNamespace
          ? WhixpUtils.xmlElement(ename, namespace: namespace)
          : WhixpUtils.xmlElement(ename);
      if (this.element == null) {
        this.element = newElement;
      } else {
        lastXML.children.add(newElement);
      }
      lastXML = newElement;
      index++;
    }

    if (parent != null) {
      parent!.element!.children.add(this.element!);
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
  XMLBase? getPlugin(String name, {String? language, bool check = false}) {
    /// If passed `language` is null, then try to retrieve it through built-in
    /// method.
    final lang = (language == null || language.isEmpty) ? _getLang : language;

    if (!pluginAttributeMapping.containsKey(name)) {
      return null;
    }

    final plugin = pluginAttributeMapping[name];

    if (plugin == null) return null;

    if (plugin.isExtension) {
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
    final lang =
        (language == null || language.isEmpty) ? defaultLanguage : language;

    late final pluginClass = pluginAttributeMapping[attribute]!;

    if (pluginClass.isExtension && _plugins[Tuple2(attribute, '')] != null) {
      return _plugins[Tuple2(attribute, '')]!;
    }
    if (reuse && _plugins[Tuple2(attribute, lang)] != null) {
      return _plugins[Tuple2(attribute, lang)]!;
    }

    late XMLBase plugin;

    if (element != null) {
      plugin = element;
    } else {
      plugin = pluginClass.copy(element: existingXML, parent: this);
    }

    if (plugin.isExtension) {
      _plugins[Tuple2(attribute, '')] = plugin;
    } else {
      if (lang != defaultLanguage) plugin['lang'] = lang;

      _plugins[Tuple2(attribute, lang)] = plugin;
    }

    if (pluginIterables.contains(pluginClass)) {
      iterables.add(plugin);
      if (pluginClass.pluginMultiAttribute != null) {
        _initPlugin(pluginClass.pluginMultiAttribute!);
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
  ///
  /// [String] or [Map] of String should be returned. If language is not defined
  /// then all sub texts will be returned.
  dynamic getSubText(
    String name, {
    String def = '',
    String? language,
  }) {
    final castedName = '/${_fixNamespace(name).value1!}';
    if (language != null && language == '*') {
      return _getAllSubText(name, def: def);
    }

    final defaultLanguage = _getLang;
    final lang =
        (language == null || language.isEmpty) ? defaultLanguage : language;

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

  /// Returns all sub text of the element.
  Map<String, String> _getAllSubText(
    String name, {
    String def = '',
    String? language,
  }) {
    final castedName = _fixNamespace(name).value1!;

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
    final lang =
        (language == null || language.isEmpty) ? defaultLanguage : language;

    if ((text == null || text.isEmpty) && !keep) {
      deleteSub(name, language: lang);
      return null;
    }

    final path = _fixNamespace(name, split: true).value2!;
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

  /// Set text to wherever sub element under [name].
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
    final path = _fixNamespace(name, split: true).value2!;
    final originalTarget = path.last;

    final defaultLanguage = _getLang;
    final lang =
        (language == null || language.isEmpty) ? defaultLanguage : language;

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

  Tuple2<String?, List<String>?> _fixNamespace(
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
  String getAttribute(String name, [String def = '']) {
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

  /// Deletes attribute under [name] If there is not [element] associated,
  /// returns from the function.
  void deleteAttribute(String name) {
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
  /// (or `foo` getter where the interface is named `foo`, etc).
  ///
  /// The search order for interface value retrieval for an interface named
  /// `foo` is:
  /// * The list of substanzas (`substanzas`)
  /// * The result of calling the `getFood` override handler
  /// * The result of calling `foo` getter
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
    final Map<String, String?> args = (languageInterfaces.contains(language) &&
            languageInterfaces.contains(attribute))
        ? {'lang': language}
        : {};

    if (attribute == 'substanzas') {
      return iterables;
    } else if (interfaces.contains(attribute) || attribute == 'lang') {
      final getMethod = attribute.toLowerCase();

      if (pluginOverrides.isNotEmpty) {
        final name = pluginOverrides[getMethod];

        if (name != null && name.isNotEmpty) {
          final plugin = getPlugin(name, language: language);

          if (plugin != null) {
            final handler = plugin._getters[Symbol(getMethod)];

            if (handler != null) return handler.call(args['lang'], plugin);
          }
        }
      }
      if (_getters.containsKey(Symbol(getMethod))) {
        return _getters[Symbol(getMethod)]?.call(args['lang'], this);
      } else {
        if (subInterfaces.contains(attribute)) {
          return getSubText(attribute, language: language);
        } else if (boolInterfaces.contains(attribute)) {
          return element!.getElement(attribute, namespace: namespace) != null;
        } else {
          return getAttribute(attribute);
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
  /// (or `foo` setter where the interface is named `foo`, etc.).
  void operator []=(String attribute, dynamic value) {
    final fullAttribute = attribute;
    final attributeLanguage = '$attribute|'.split('|');
    final attrib = attributeLanguage[0];
    final lang = attributeLanguage[1].isEmpty ? null : attributeLanguage[1];
    final args = <String, String?>{};

    if (languageInterfaces.contains(lang) &&
        languageInterfaces.contains(attrib)) {
      args['lang'] = lang;
    }

    if (interfaces.contains(attrib) || attrib == 'lang') {
      if (value != null) {
        final setMethod = attrib.toLowerCase();

        if (pluginOverrides.isNotEmpty) {
          final name = pluginOverrides[setMethod];

          if (name != null && name.isNotEmpty) {
            final plugin = getPlugin(name, language: lang);

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
          if (subInterfaces.contains(attrib)) {
            dynamic subvalue;
            if (value is JabberID) {
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
          } else if (boolInterfaces.contains(attrib)) {
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
              (value != null && value is JabberID)
                  ? value.toString()
                  : value as String?,
            );
          }
        }
      }
    } else if (pluginAttributeMapping.containsKey(attrib) &&
        pluginAttributeMapping[attrib] != null) {
      final plugin = getPlugin(attrib, language: lang);
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

    if (languageInterfaces.contains(lang) &&
        languageInterfaces.contains(attrib)) {
      args['lang'] = lang;
    }

    if (interfaces.contains(attrib) || attrib == 'lang') {
      final deleteMethod = attrib.toLowerCase();

      if (pluginOverrides.isNotEmpty) {
        final name = pluginOverrides[deleteMethod];

        if (name != null && name.isNotEmpty) {
          final plugin = getPlugin(attrib, language: lang);

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
        if (subInterfaces.contains(attrib)) {
          return deleteSub(attrib, language: lang);
        } else if (boolInterfaces.contains(attrib)) {
          return deleteSub(attrib, language: lang);
        } else {
          return deleteAttribute(attrib);
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
      element?.children.add(base.element!);
      if (base == pluginTagMapping[base._tagName]) {
        _initPlugin(
          base.pluginAttribute,
          existingXML: base.element,
          element: base,
          reuse: false,
        );
      } else if (pluginIterables.contains(base)) {
        iterables.add(base);
        if (base.pluginMultiAttribute != null &&
            base.pluginMultiAttribute!.isNotEmpty) {
          _initPlugin(base.pluginMultiAttribute!);
        }
      } else {
        iterables.add(base);
      }
    }

    return this;
  }

  /// Adds child element to the underlying XML element.
  XMLBase _addXML(xml.XmlElement element) =>
      this..element!.children.add(element);

  /// Returns the namespaced name of the stanza's root element.
  ///
  /// The format for the tag name is: '{namespace}elementName'.
  String get _tagName => '{$namespace}$name';

  /// Gets current language of the xml element with xPath query.
  String? _lang(xml.XmlNode element) {
    final result = element
        .queryXPath(
          "//@*[local-name()='xml:lang' and namespace-uri()='${WhixpUtils.getNamespace('XML')}']",
        )
        .node;

    if (result == null) return null;

    return result.node.getAttribute('xml:lang');
  }

  /// Gets language from underlying parent.
  String get _getLang {
    if (element == null) return '';

    final result = _lang(element!);
    if (result == null && parent != null) {
      return parent!['lang'] as String;
    }
    return result ?? '';
  }

  /// Getter for stanza plugins list.
  Map<Tuple2<String, String>, XMLBase> get plugins => _plugins;

  /// Compares a stanza object with an XPath-like expression.
  ///
  /// If the XPath matches the contents o the stanza obejct, the match is
  /// succesfull.
  ///
  /// The XPath expression may include checks for stanza attributes.
  bool match(Tuple2<String?, List<String>?> xPath) {
    late List<String> xpath;
    if (xPath.value1 != null) {
      xpath = _fixNamespace(xPath.value1!, split: true).value2!;
    } else {
      xpath = xPath.value2!;
    }

    /// Extract the tag name and attribute checks for the first XPath node
    final components = xpath[0].split('@');
    final tag = components[0];
    final attributes = components.sublist(1);

    if (!{name, '{$namespace}$name'}.contains(tag) &&
        !_loadedPlugins.contains(tag) &&
        !pluginAttribute.contains(tag)) {
      return false;
    }

    /// Checks the rest of the XPath against any substanzas
    bool matchedSubstanzas = false;
    for (final substanza in iterables) {
      if (xpath.sublist(1).isEmpty) {
        break;
      }
      matchedSubstanzas = substanza.match(Tuple2(null, xpath.sublist(1)));
      if (matchedSubstanzas) {
        break;
      }
    }

    /// Checks attribute values
    for (final attribute in attributes) {
      final name = attribute.split('=')[0];
      final value = attribute.split('=')[1];

      if (this[name] != value) {
        return false;
      }
    }

    /// Checks sub interfaces
    if (xpath.length > 1) {
      final nextTag = xpath[1];
      if (subInterfaces.contains(nextTag) && this[nextTag] != null) {
        return true;
      }
    }

    /// Attempt to continue matching the XPath using the stanza's plugin
    if (!matchedSubstanzas && xpath.length > 1) {
      final nextTag = xpath[1].split('@')[0].split('}').last;
      final languages = <String>[];

      for (final entry in _plugins.entries) {
        if (entry.key.value1 == nextTag) {
          languages.add(entry.key.value2);
        }
      }

      for (final language in languages) {
        final plugin = getPlugin(nextTag, language: language);
        if (plugin != null && plugin.match(Tuple2(null, xpath.sublist(1)))) {
          return true;
        }
      }
      return false;
    }

    /// Everything matched
    return true;
  }

  /// Returns the names of all stanza interfaces provided by the stanza object.
  ///
  /// Allows stanza objects to be used as [Map].
  List<String> get keys {
    final buffer = <String>[];
    for (final x in interfaces) {
      buffer.add(x);
    }
    for (final x in _loadedPlugins) {
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
        element!.children.remove(stanza.element);
      }
      iterables.clear();

      final substanzas = values['substanzas'] as List<Map<String, dynamic>>;
      for (final submap in substanzas) {
        if (submap.containsKey('__childtag__')) {
          for (final subclass in pluginIterables) {
            final childtag = '{${subclass.namespace}}${subclass.name}';
            if (submap['__childtag__'] == childtag) {
              final sub = subclass.copy(parent: this);
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
      final language = interfaceLanguage[1];
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
    return;
  }

  /// Returns a JSON/Map version of the XML content exposed through the stanza's
  /// interfaces.
  Map<String, dynamic> get _values {
    final values = <String, dynamic>{};
    values['lang'] = this['lang'];

    for (final interface in interfaces) {
      if (this[interface] is JabberID) {
        values[interface] = (this[interface] as JabberID).jid;
      } else {
        values[interface] = this[interface];
      }
      if (languageInterfaces.contains(interface)) {
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
    if (iterables.isNotEmpty) {
      final iter = <Map<String, dynamic>>[];
      for (final stanza in iterables) {
        iter.add(stanza.values);
        if (iter.length - 1 >= 0) {
          iter[iter.length - 1]['__childtag__'] = stanza.tag;
        }
      }
      values['substanzas'] = iter;
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

  /// Returns a JSON/Map version of the XML content exposed through the stanza's
  /// interfaces.
  Map<String, dynamic> get values => _values;

  /// Set multiple stanza interface [values] using [Map].
  ///
  /// Stanza plugin values may be set using nested [Map]s.
  set values(Map<String, dynamic> values) => _values = values;

  /// Getter for private [Map] [_getters].
  Map<Symbol, _GetterOrDeleter> get getters => _getters;

  /// Getter for private [Map] [_setters].
  Map<Symbol, _Setter> get setters => _setters;

  /// Getter for private [Map] [_deleters].
  Map<Symbol, _GetterOrDeleter> get deleters => _deleters;

  /// You need to override this method in order to create a copy from an
  /// existing object due Dart do not have deep copy support for now.
  ///
  /// ### Example:
  /// ```dart
  /// class SimpleStanza extends XMLBase {
  ///   SimpleStanza({super.element, super.parent});
  ///
  ///   @override
  ///   XMLBase copy({xml.XmlElement? element, XMLBase? parent}) =>
  ///     SimpleStanza(element: element, parent: parent);
  /// }
  /// ```
  XMLBase copy({xml.XmlElement? element, XMLBase? parent}) => XMLBase(
        name: name,
        namespace: namespace,
        pluginAttribute: pluginAttribute,
        pluginMultiAttribute: pluginMultiAttribute,
        overrides: overrides,
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        interfaces: interfaces,
        subInterfaces: subInterfaces,
        boolInterfaces: boolInterfaces,
        languageInterfaces: languageInterfaces,
        pluginIterables: pluginIterables,
        getters: _getters,
        setters: _setters,
        deleters: _deleters,
        isExtension: isExtension,
        includeNamespace: includeNamespace,
        element: element,
        parent: parent,
      );

  /// Add a custom getter function to the [XMLBase] class, allowing users to
  /// extend behavior of the class by defining custom getters for specific
  /// attributes.
  ///
  /// ### Example:
  /// ```dart
  /// final base = XMLBase('someStanza');
  /// base.addGetters({Symbol('value'): (args, base) {
  ///   base.element.children!.remove(someChild); /// calling "value" getter will remove child
  /// }});
  /// ```
  void addGetters(Map<Symbol, _GetterOrDeleter> getters) =>
      _getters.addAll(getters);

  /// Adds custom setter functions to the [XMLBase] class, enabling users to
  /// extend the class by defining custom setters for specific attributes.
  ///
  /// ### Example:
  /// ```dart
  /// final base = XMLBase('someStanza');
  /// base.addSetters({Symbol('value'): (args, value, base) {
  ///   base.element.children!.remove(someChild); /// calling "value" setter will remove child
  /// }});
  /// ```
  void addSetters(Map<Symbol, _Setter> setters) => _setters.addAll(setters);

  /// Adds custom deleter functions to the [XMLBase] class, allowing users to
  /// extend the class by defining custom deleter functions for specific
  /// attributes.
  ///
  /// ### Example:
  /// ```dart
  /// final base = XMLBase('someStanza');
  /// base.addDeleters({Symbol('value'): (args, value, base) {
  ///   base.element.children!.remove(someChild); /// calling "value" setter will remove child
  /// }});
  /// ```
  void addDeleters(Map<Symbol, _GetterOrDeleter> deleters) =>
      _deleters.addAll(deleters);

  /// When iterating over [XMLBase], helps to increment our plugin index.
  void _incrementIndex() => _index++;

  /// Returns a string serialization of the underlying XML object.
  @override
  String toString() => WhixpUtils.serialize(element) ?? '';
}

/// Extender for [registerStanzaPlugin] method.
extension RegisterStanza on XMLBase {
  /// Does what [registerStanzaPlugin] does. But without primary stanza. 'Cause
  /// it is called as the part of the primary stanza and do not need it to
  /// passed.
  ///
  /// [iterable] flag indicates if the plugin stanza should be included in the
  /// parent stanza's iterable [substanzas] interface results.
  ///
  /// [overrides] flag indicates if the plugin should be allowed to override the
  /// interface handlers for the parent stanza, based on the plugin's
  /// [overrides] field.
  void registerPlugin(
    XMLBase plugin, {
    bool iterable = false,
    bool overrides = false,
  }) =>
      registerStanzaPlugin(
        this,
        plugin,
        iterable: iterable,
        overrides: overrides,
      );
}
