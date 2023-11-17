import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/stream/base.dart';

/// Create and compare several stanza objects to a correct XML string.
void check(
  XMLBase stanza,
  XMLBase baseStanza, {
  String? method = 'exact',
  bool useValues = true,
}) {
  print(stanza);
  fixNamespace(baseStanza..namespace = '');
  print(baseStanza);
}

/// Assign a [namespace] to an element and any children that do not have a
/// namespace.
void fixNamespace(
  XMLBase base, [
  String? namespace,
]) {
  final ns = namespace ?? Echotils.getNamespace('CLIENT');
  if (base.tag.startsWith('{')) return;

  base.tag = '{$ns}${base.tag}';

  for (final child in base.toIterable()) {
    fixNamespace(child, namespace);
  }
}
