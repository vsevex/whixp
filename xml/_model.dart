part of 'base.dart';

class ElementModel {
  const ElementModel(this.name, this.namespace, {this.xml, this.parent});

  final String name;
  final String? namespace;
  final XmlElement? xml;
  final BaseElement? parent;

  String _getter(String? data) => data ?? 'NOT included';

  @override
  String toString() =>
      '''Element Model: namespace => ${_getter(namespace)}, parent => ${parent?._name}''';

  @override
  bool operator ==(Object element) =>
      element is ElementModel &&
      element.name == name &&
      element.namespace == namespace &&
      element.xml == xml &&
      element.parent == parent;

  @override
  int get hashCode =>
      name.hashCode ^ namespace.hashCode ^ xml.hashCode ^ parent.hashCode;
}
