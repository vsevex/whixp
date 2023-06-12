part of 'vcard_extension.dart';

/// [VCard] represents a vCard containing personal information.
///
/// A vCard is a standardized format format for representing and exchanging
/// personal information.
///
/// This class provides properties to store various details such as the full
/// name, nickname, photo, email address, and phone number associated with
/// a person.
class VCard {
  /// Constructs a [VCard] object with the specified required and optional
  /// properties.
  const VCard(
    this.fullName, {
    this.nickname,
    this.photo,
    this.email,
    this.phoneNumber,
  });

  /// The full name of the person.
  final String fullName;

  /// The nickname of preferred name of the person.
  final String? nickname;

  /// The photo or avatar of the person.
  final String? photo;

  /// The email address associated with the person.
  final String? email;

  /// The phone number associated with the person.
  final String? phoneNumber;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VCard &&
          runtimeType == other.runtimeType &&
          fullName == other.fullName &&
          nickname == other.nickname &&
          photo == other.photo &&
          email == other.email &&
          phoneNumber == other.phoneNumber;

  @override
  int get hashCode =>
      fullName.hashCode ^
      nickname.hashCode ^
      photo.hashCode ^
      email.hashCode ^
      phoneNumber.hashCode;
}
