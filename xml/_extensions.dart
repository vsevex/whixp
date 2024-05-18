part of 'base.dart';

extension Attribute on BaseElement {
  String getAttribute(
    String attribute, [
    String absence = '',
    String? namespace,
  ]) {
    if (attribute == 'lang' || attribute == 'language') {
      return _xml.getAttribute(_xmlLanguage, namespace: namespace) ?? absence;
    } else {
      return _xml.getAttribute(attribute, namespace: namespace) ?? absence;
    }
  }

  void setAttribute(String attribute, [String? value, String? namespace]) {
    if (value == null) return deleteAttribute(attribute, namespace);
    if (attribute == 'lang' || attribute == 'language') {
      _xml.setAttribute(_xmlLanguage, value, namespace: namespace);
    } else {
      _xml.setAttribute(attribute, value, namespace: namespace);
    }
  }

  void deleteAttribute(String attribute, [String? namespace]) =>
      _xml.removeAttribute(attribute, namespace: namespace);
}

extension SubTextGetters on BaseElement {
  String getSubText(String name, {String absence = '', String? language}) {
    assert(
      language != '*',
      'Instead call `getAllSubtext` to get all language texts',
    );

    final stanzas = _xml.findAllElements(name);
    if (stanzas.isEmpty) return absence;

    String? result;
    for (final stanza in stanzas) {
      if (_lang(stanza) == language) {
        if (stanza.innerText.isEmpty) return absence;

        result = stanza.innerText;
        break;
      }
      if (stanza.innerText.isNotEmpty) {
        result = stanza.innerText;
      }
    }

    return result ?? absence;
  }

  Map<String?, String> getAllSubText(
    String name, {
    String absence = '',
    String? language,
  }) {
    final casted = _fixedNamespace(name).join('/');

    final results = <String?, String>{};
    final stanzas = _xml.findAllElements(casted);
    if (stanzas.isNotEmpty) {
      for (final stanza in stanzas) {
        final stanzaLanguage = _lang(stanza) ?? defaultLanguage;

        if (language == stanzaLanguage || language == '*') {
          late String text;
          if (stanza.innerText.isEmpty) {
            text = absence;
          } else {
            text = stanza.innerText;
          }

          results[stanzaLanguage] = text;
        }
      }
    }

    return results;
  }
}

extension SubTextSetters on BaseElement {
  XmlNode? setSubText(
    String name, {
    String text = '',
    String? language,
    bool keep = false,
  }) {
    /// Set language to an empty string beforehand, 'cause it will lead to
    /// unexpected behaviour like adding an empty language key to the stanza.
    language = language ?? '';
    final lang = language.isNotEmpty ? language : defaultLanguage;

    if (text.isEmpty && !keep) {
      removeSubElement(name, language: lang);
      return null;
    }

    final path = _fixedNamespace(name);
    final casted = path.last;

    XmlNode? parent;
    final elements = <XmlNode>[];

    List<String> missingPath = <String>[];
    final searchOrder = List<String>.from(path)..removeLast();

    while (searchOrder.isNotEmpty) {
      parent = _xml.xpath('/${searchOrder.join('/')}').firstOrNull;

      final searched = searchOrder.removeLast();
      if (parent != null) break;
      missingPath.add(searched);
    }

    missingPath = missingPath.reversed.toList();

    if (parent != null) {
      elements.addAll(_xml.xpath('/${path.join('/')}'));
    } else {
      parent = _xml;
      elements.clear();
    }

    for (final missing in missingPath) {
      final temporary = WhixpUtils.xmlElement(missing);
      parent?.children.add(temporary);
      parent = temporary;
    }

    for (final element in elements) {
      final language = _lang(element) ?? defaultLanguage;
      if ((lang == null && language == defaultLanguage) || lang == language) {
        _xml.innerText = text;
        return _xml;
      }
    }

    final temporary = WhixpUtils.xmlElement(casted);
    temporary.innerText = text;

    if (lang != null && lang != defaultLanguage) {
      temporary.setAttribute(_xmlLanguage, lang);
    }

    parent?.children.add(temporary);
    return temporary;
  }

  void setAllSubText(
    String name, {
    String? language,
    Map<String, String> values = const {},
  }) {
    assert(values.isNotEmpty, 'Subtext values to be set can not be empty');
    removeSubElement(name, language: language);
    for (final entry in values.entries) {
      if (language == null || language == '*' || entry.key == language) {
        setSubText(name, text: entry.value, language: entry.key);
      }
    }
  }
}

extension SubTextRemovers on BaseElement {
  void removeSubText(String name, {bool all = false, String? language}) =>
      removeSubElement(name, all: all, language: language, onlyContent: true);
}

extension SubElementRemovers on BaseElement {
  void removeSubElement(
    String name, {
    bool all = false,
    bool onlyContent = false,
    String? language,
  }) {
    final path = _fixedNamespace(name);
    final target = path.last;

    final lang = language ?? defaultLanguage;

    Iterable<int> enumerate<T>(List<T> iterable) sync* {
      for (int i = 0; i < iterable.length; i++) {
        yield i;
      }
    }

    XmlNode parent = _xml;
    for (final level in enumerate(path)) {
      final elementPath = path.sublist(0, path.length - level).join('/');
      final parentPath =
          (level > 0) ? path.sublist(0, path.length - level - 1).join('/') : '';

      final elements = _xml.xpath('/$elementPath');
      if (parentPath.isNotEmpty) {
        parent = _xml.xpath('/$parentPath').firstOrNull ?? _xml;
      }

      for (final element in elements.toList()) {
        if (element is XmlElement) {
          if (element.name.qualified == target || element.children.isEmpty) {
            final elementLanguage = _lang(element);
            if (lang == '*' || elementLanguage == lang) {
              final result = parent.children.remove(element);
              if (onlyContent && result) {
                parent.children.add(element..innerText = '');
              }
            }
          }
        }
      }

      if (!all) return;
    }
  }
}

extension XMLManipulator on BaseElement {
  XmlElement get xml => _xml;

  Iterable<XmlElement> get childElements => _xml.childElements;

  XmlElement? getElement(String name) => _xml.getElement(name);
}

extension Registrator on BaseElement {
  void register(String name, BaseElement element) =>
      _ElementPluginRegistrator().register(name, element);

  void unregister(String name) => _ElementPluginRegistrator().unregister(name);
}

extension Interfaces on BaseElement {
  void setInterface(String name, String value, {String? language}) {
    final lang = language ?? defaultLanguage;
    assert(lang != '*', 'Use `setInterfaces` method instead');

    setSubText(name, text: value, language: lang);
  }

  void setInterfaces(
    String name,
    Map<String, String> values, {
    String? language,
  }) {
    final lang = language ?? defaultLanguage;

    return setAllSubText(name, values: values, language: lang);
  }

  List<XmlElement> getInterfaces(String name, {String? language}) {
    final lang = language ?? defaultLanguage;

    final elements = _xml.findAllElements(name);
    final interfaces = <XmlElement>[];
    if (elements.isEmpty) return interfaces;

    for (final element in elements) {
      if (_lang(element) == lang || lang == '*') {
        interfaces.add(element);
      }
    }

    return interfaces;
  }

  void removeInterface(String name, {String? language}) {
    final lang = language ?? defaultLanguage;

    if (_plugins.contains(name)) {
      final plugin = get(name, language: lang);
      if (plugin == null) return;

      _registeredPlugins.remove(name);
      _xml.children.remove(plugin._xml);
    } else {
      removeSubElement(name, language: lang);
    }
  }

  XmlNode? setEmptyInterface(String name, bool value, {String? language}) {
    if (value) {
      return setSubText(name, keep: true, language: language);
    } else {
      return setSubText(name, language: language);
    }
  }

  bool containsInterface(String name) => _xml.getElement(name) != null;
}

extension Language on BaseElement {
  String? _lang([XmlNode? xml]) {
    if (xml != null) {
      return xml
          .copy()
          .xpath('//*[@$_xmlLanguage]')
          .firstOrNull
          ?.getAttribute(_xmlLanguage);
    }

    /// Get default language by the lookup to the root element of the root
    /// element.
    return _xml.getAttribute(_xmlLanguage);
  }
}

extension Tag on BaseElement {
  String get tag {
    if (_namespace != null) {
      return '$_namespace$_name';
    }
    return _name;
  }
}
