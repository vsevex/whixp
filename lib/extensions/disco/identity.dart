part of 'disco_extension.dart';

/// Represents a `Disco Identity`.
///
/// A Disco Identity contains information about the category, type, name, and
/// language associated with an identity.
///
/// ### For example: `account` Service Discovery Identities.
///
/// The `account` category is to be used by a server when responding to a disco
/// request sent to the bare JID (user@example.com address) of an account hosted
/// by the server.
class DiscoIdentity {
  /// Creates a [DiscoIdentity] with the provided parameters.
  const DiscoIdentity({
    required this.category,
    required this.type,
    this.name,
    this.language,
  });

  /// The category of the identity.
  final String category;

  /// The type of the identity.
  final String type;

  /// The name of the identity.
  ///
  /// This value is optional and can be `null`.
  final String? name;

  /// The language associated with the identity.
  ///
  /// This value is optional and can be `null`.
  final String? language;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoIdentity &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          type == other.type &&
          name == other.name &&
          language == other.language;

  @override
  int get hashCode =>
      category.hashCode ^ type.hashCode ^ name.hashCode ^ language.hashCode;

  @override
  String toString() =>
      '''Disco Identity: (Category: $category, Type: $type, Name: $name, Language: $language)''';
}
