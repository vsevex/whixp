part of 'disco_extension.dart';

typedef VoidCallback = List<DiscoItem> Function(XmlElement);

/// Represents a `Disco Item`.
///
/// A Disco Item contains an information about a JID (Jabber Identifier), along
/// with an optional name, node, and a callback function.
class DiscoItem {
  /// Creates a [DiscoItem] with the provided parameters.
  const DiscoItem({
    required this.jid,
    this.name,
    this.node,
    required this.callback,
  });

  /// The `jid` parameter is required and represents the JID associated with
  /// an item.
  final String jid;

  /// The `name` associated with the item.
  ///
  /// This value is optional and can be `null`.
  final String? name;

  /// The `node` associated with the item.
  ///
  /// This value is optional and can be `null`.
  final String? node;

  /// The callback function to be executed.
  final VoidCallback callback;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoItem &&
          runtimeType == other.runtimeType &&
          jid == other.jid &&
          name == other.name &&
          node == other.node &&
          callback == other.callback;

  @override
  int get hashCode =>
      jid.hashCode ^ name.hashCode ^ node.hashCode ^ callback.hashCode;

  @override
  String toString() =>
      '''Disco Item: (JID: $jid, Name: $name, Node: $node, Callback: $callback)''';
}
