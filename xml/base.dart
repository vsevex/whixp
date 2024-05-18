import 'package:dartz/dartz.dart';

import 'package:whixp/src/exception.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart';
import 'package:xml/xpath.dart';

import 'stanza.dart';

part '_extensions.dart';
part '_model.dart';
part '_registrator.dart';
part '_static.dart';

List<String> _fixNamespace(
  String xPath, {
  String? absenceNamespace,
  bool propogateNamespace = true,
}) {
  final fixed = <String>[];

  final namespaceBlocks = xPath.split('{');
  for (final block in namespaceBlocks) {
    late String? namespace;
    late List<String> elements;
    if (block.contains('}')) {
      final namespaceBlockSplit = block.split('}');
      namespace = namespaceBlockSplit[0];
      elements = namespaceBlockSplit[1].split('/');
    } else {
      namespace = absenceNamespace;
      elements = block.split('/');
    }

    for (final element in elements) {
      late String tag;
      if (element.isNotEmpty) {
        if (propogateNamespace && element[0] != '*') {
          if (namespace != null) {
            tag = '<$element xmlns="$namespace"/>';
          } else {
            tag = '<$element/>';
          }
        } else {
          tag = element;
        }
        fixed.add(tag);
      }
    }
  }

  return fixed;
}

abstract class BaseElement implements BaseElementFactory {
  BaseElement(
    String name, {
    String? namespace,
    Set<String> plugins = const <String>{},
    XmlElement? xml,
    BaseElement? parent,
  }) {
    _name = name;
    _namespace = namespace;
    _parent = parent;
    _plugins = plugins;

    /// Whenever the element is initialized, create an empty list of plugins.
    _registeredPlugins = <String, Tuple2<String?, BaseElement>>{};

    final parse = !_setup(xml);

    if (parse) {
      final childElements = _xml.childElements.toList().reversed.toList();
      final elements = <Tuple2<XmlElement, BaseElement>>[];

      if (childElements.isEmpty) return;

      for (final element in childElements) {
        final name = element.localName;

        if (_plugins.contains(name)) {
          final plugin = _ElementPluginRegistrator().get(name);
          elements.add(Tuple2(element, plugin));
        }
      }

      for (final element in elements) {
        _initPlugin(element.value2._name, element.value1, element.value2);
      }
    }
  }

  late final String _name;
  late final String? _namespace;
  late final XmlElement _xml;
  late final BaseElement? _parent;
  late final Set<String> _plugins;
  late final Map<String, Tuple2<String?, BaseElement>> _registeredPlugins;

  bool _setup([XmlElement? xml]) {
    _ElementPluginRegistrator().register(_name, this);
    if (xml != null) {
      _xml = xml;
      return false;
    }

    final parts = _name.split('/');

    XmlElement? lastxml;
    for (final splitted in parts) {
      final newxml = lastxml == null
          ? WhixpUtils.xmlElement(splitted, namespace: _namespace)
          : WhixpUtils.xmlElement(splitted);

      if (lastxml == null) {
        lastxml = newxml;
      } else {
        lastxml.children.add(newxml);
      }
    }

    _xml = lastxml ?? XmlElement(XmlName(''));

    if (_parent != null) {
      _parent._xml.children.add(_xml);
    }

    return true;
  }

  BaseElement _initPlugin(
    String pluginName,
    XmlElement existingXml,
    BaseElement currentElement, {
    String? language,
  }) {
    final name = existingXml.localName;
    final namespace = existingXml.getAttribute('xmlns');
    final plugin = BaseElementFactory.parse(
      currentElement,
      ElementModel(name, namespace, xml: existingXml, parent: this),
    );
    final lang = language ?? defaultLanguage;

    _registeredPlugins[pluginName] = Tuple2(lang, plugin);

    return plugin;
  }

  List<String> _fixedNamespace(String xPath) => _fixNamespace(
        xPath,
        absenceNamespace: _namespace,
        propogateNamespace: false,
      );

  E? get<E extends BaseElement>(
    String name, {
    String? language,
    bool fallbackInitialize = false,
  }) {
    final lang = language ?? defaultLanguage;

    BaseElement? plugin;
    if (_registeredPlugins.containsKey(name)) {
      final existing = _registeredPlugins[name];
      if (existing != null && existing.value1 == lang) {
        plugin = existing.value2;
      }
    } else if (fallbackInitialize) {
      final element = _xml.getElement(name);
      if (element != null) {
        plugin = _initPlugin(name, element, this, language: lang);
      }
    }

    try {
      final casted = plugin as E?;
      return casted;
    } on Exception {
      throw WhixpInternalException(
        'Type ${plugin.runtimeType} can not be casted to the ${E.runtimeType} type',
      );
    }
  }

  set defaultLanguage(String? language) => setAttribute(_xmlLanguage, language);

  String? get defaultLanguage => _lang();

  @override
  String toString() => WhixpUtils.serialize(_xml) ?? '';

  @override
  bool operator ==(Object element) =>
      element is BaseElement &&
      element._name == _name &&
      element._namespace == _namespace &&
      element._xml == _xml &&
      element._parent == _parent;

  @override
  int get hashCode =>
      _name.hashCode ^ _namespace.hashCode ^ _xml.hashCode ^ _parent.hashCode;
}
