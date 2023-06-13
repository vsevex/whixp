import 'package:echo/echo.dart';

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
  ///
  /// ### Usage
  /// ```dart
  /// final vCard = VCard(
  ///   fullName: 'Vsevolod V. Melyukov',
  ///   nickname: 'vsevex',
  ///   photo: 'base64String',
  ///   email: 'vsevex@gmail.com',
  ///   jabberID: 'vsevex',
  /// );
  ///
  /// This constructs a [VCard] object with the given information.
  /// ```
  const VCard({
    this.fullName,
    this.nickname,
    this.photo,
    this.email,
    this.phoneNumber,
    this.timezone,
    this.jabberID,
  });

  /// The full name of the person.
  final String? fullName;

  /// The nickname of preferred name of the person.
  final String? nickname;

  /// The photo or avatar of the person.
  final String? photo;

  /// The email address associated with the person.
  final String? email;

  /// The phone number associated with the person.
  final String? phoneNumber;

  /// The timezone that is related with the user's geolocation.
  final String? timezone;

  /// The JabberID of the accepted user.
  final String? jabberID;

  /// Generates a list of [XmlElement] objects representing the payload of the
  /// vCard.
  ///
  /// Each element corresponds to a property of the vCard that has a non-null
  /// value.
  ///
  /// The returned list contains elements in the following format:
  /// - 'FN': Full Name
  /// - 'NICKNAME': Nickname
  /// - 'PHOTO': Photo
  /// - 'EMAIL': Email
  /// - 'TEL': Phone Number
  /// - 'TZ': Timezone
  List<XmlElement> get payload {
    final elements = <XmlElement>[];
    if (fullName != null) {
      elements.add(_xmlCreator('FN', fullName!));
    }
    if (nickname != null) {
      elements.add(_xmlCreator('NICKNAME', nickname!));
    }
    if (photo != null) {
      elements.add(_xmlCreator('PHOTO', photo!));
    }
    if (email != null) {
      elements.add(_xmlCreator('EMAIL', email!));
    }
    if (phoneNumber != null) {
      elements.add(_xmlCreator('TEL', phoneNumber!));
    }
    if (timezone != null) {
      elements.add(_xmlCreator('TZ', timezone!));
    }

    return elements;
  }

  /// Creates an [XmlElement] with the specified [name] and [value].
  ///
  /// The [name] parameter represents the name of the element, and the [value]
  /// parameter represents the text value of the element.
  XmlElement _xmlCreator(String name, String value) =>
      Echotils.xmlElement(name, text: value)!;

  VCard copyWith({
    /// The full name of the person.
    String? fullName,

    /// The nickname of preferred name of the person.
    String? nickname,

    /// The photo or avatar of the person.
    String? photo,

    /// The email address associated with the person.
    String? email,

    /// The phone number associated with the person.
    String? phoneNumber,

    /// The timezone that is related with the user's geolocation.
    String? timezone,

    /// The JabberID of the accepted user.
    String? jabberID,
  }) =>
      VCard(
        fullName: fullName ?? this.fullName,
        nickname: nickname ?? this.nickname,
        photo: photo ?? this.photo,
        email: email ?? this.email,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        timezone: timezone ?? this.timezone,
        jabberID: jabberID ?? this.jabberID,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VCard &&
          runtimeType == other.runtimeType &&
          fullName == other.fullName &&
          nickname == other.nickname &&
          photo == other.photo &&
          email == other.email &&
          phoneNumber == other.phoneNumber &&
          timezone == other.timezone &&
          jabberID == other.jabberID;

  @override
  int get hashCode =>
      fullName.hashCode ^
      nickname.hashCode ^
      photo.hashCode ^
      email.hashCode ^
      phoneNumber.hashCode ^
      timezone.hashCode ^
      jabberID.hashCode;

  @override
  String toString() =>
      '''VCard: (Full Name: $fullName, Nickname: $nickname, Photo: $photo, Email: $email, Phone Number: $phoneNumber, Time Zone: $timezone)''';
}
