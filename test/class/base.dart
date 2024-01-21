import 'package:whixp/src/stream/base.dart';

XMLBase createTestStanza({
  required String name,
  String? namespace,
  String pluginAttribute = 'plugin',
  String? pluginMultiAttribute,
  List<String> overrides = const <String>[],
  Set<String> interfaces = const <String>{},
  Set<String> subInterfaces = const <String>{},
  Set<String> boolInterfaces = const <String>{},
  Set<String> languageInterfaces = const <String>{},
  Map<Symbol, void Function(dynamic, XMLBase)>? getters,
  Map<Symbol, void Function(dynamic value, dynamic args, XMLBase)>? setters,
  Map<Symbol, void Function(dynamic, XMLBase)>? deleters,
  bool isExtension = false,
  bool includeNamespace = true,
}) =>
    _TestStanza(
      name: name,
      namespace: namespace,
      pluginAttribute: pluginAttribute,
      pluginMultiAttribute: pluginMultiAttribute,
      overrides: overrides,
      interfaces: interfaces,
      subInterfaces: subInterfaces,
      boolInterfaces: boolInterfaces,
      languageInterfaces: languageInterfaces,
      getters: getters,
      setters: setters,
      deleters: deleters,
      isExtension: isExtension,
      includeNamespace: includeNamespace,
    );

class _TestStanza extends XMLBase {
  _TestStanza({
    super.name,
    super.namespace,
    super.pluginAttribute,
    super.pluginMultiAttribute,
    super.overrides,
    super.interfaces,
    super.subInterfaces,
    super.boolInterfaces,
    super.languageInterfaces,
    super.getters,
    super.setters,
    super.deleters,
    super.isExtension,
    super.includeNamespace,
  });
}

class MultiTestStanza2 extends XMLBase {
  MultiTestStanza2({
    super.name,
    super.namespace,
    super.pluginAttribute,
    super.pluginMultiAttribute,
    super.includeNamespace = true,
    super.element,
    super.parent,
  });
}
