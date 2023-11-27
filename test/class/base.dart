import 'package:echox/src/stream/base.dart';

import 'package:xml/src/xml/nodes/element.dart';

XMLBase createTestStanza({
  String? name,
  String? namespace,
  String? pluginAttribute,
  String? pluginMultiAttribute,
  List<String>? overrides,
  Set<String>? interfaces,
  Set<String>? subInterfaces,
  Set<String>? boolInterfaces,
  Set<String>? languageInterfaces,
  Map<Symbol, void Function(dynamic, XMLBase)>? getters,
  Map<Symbol, void Function(dynamic value, dynamic args, XMLBase)>? setters,
  Map<Symbol, void Function(dynamic, XMLBase)>? deleters,
  bool isExtension = false,
  bool includeNamespace = true,
  void Function(XMLBase base, [XmlElement? element])? setupOverride,
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
      setupOverride: setupOverride,
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
    this.setupOverride,
  });

  final void Function(XMLBase base, [XmlElement? element])? setupOverride;

  @override
  bool setup([XmlElement? element]) {
    setupOverride?.call(this, element);
    return super.setup(element);
  }
}
