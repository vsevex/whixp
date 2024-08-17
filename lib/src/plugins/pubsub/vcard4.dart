part of 'pubsub.dart';

/// The `VCard4` class represents a vCard 4.0, which is a standard for
/// electronic business cards.
///
/// This class extends [IQStanza] and includes properties for a person's full
/// name, surnames, usernames, photo, birthday, and email.
class VCard4 extends IQStanza {
  /// Creates an instance of `VCard4`.
  const VCard4({
    this.fullname,
    this.uid,
    this.surnames,
    this.username,
    this.photo,
    this.binval,
    this.bday,
    this.email,
    this.gender,
  });

  /// The full name of the person.
  final String? fullname;

  /// The UID of the vCard.
  final String? uid;

  /// A map containing the person's surnames, with keys for 'surname', 'given',
  /// and 'additional'.
  final Map<String, String>? surnames;

  /// A list of usernames or nicknames for the person.
  final List<String>? username;

  /// A URI to the person's photo.
  final String? photo;

  /// A BINVAL to the person's photo in base64.
  final String? binval;

  /// The person's birthday.
  final String? bday;

  /// The person's email address.
  final String? email;

  /// Person's gender.
  final String? gender;

  /// Creates a `VCard4` instance from an XML element.
  ///
  /// - [node]: An XML element representing a vCard 4.0.
  factory VCard4.fromXML(xml.XmlElement node) {
    String? fullname;
    String? uid;
    final surnames = <String, String>{};
    final usernames = <String>[];
    String? photo;
    String? binval;
    String? bday;
    String? email;
    String? gender;

    // Iterate over the child elements of the node to extract vCard information
    for (final child in node.children.whereType<xml.XmlElement>()) {
      switch (child.localName) {
        case 'fn':
          final text = child.getElement('text');
          if (text != null) {
            fullname = text.innerText;
          }
        case 'uid':
          final text = child.getElement('text');
          if (text != null) {
            uid = text.innerText;
          }
        case 'n':
          if (child.getElement('surname') != null) {
            surnames['surname'] = child.getElement('surname')!.innerText;
          }
          if (child.getElement('given') != null) {
            surnames['given'] = child.getElement('given')!.innerText;
          }
          if (child.getElement('additional') != null) {
            surnames['additional'] = child.getElement('additional')!.innerText;
          }
        case 'nickname':
          final text = child.getElement('text');
          if (text != null) {
            usernames.add(text.innerText);
          }
        case 'photo':
          final uri = child.getElement('uri');
          final bin = child.getElement('BINVAL');
          if (uri != null) {
            photo = uri.innerText;
          }
          if (bin != null) {
            binval = bin.innerText;
          }
        case 'bday':
          final date = child.getElement('date');
          if (date != null) {
            bday = date.innerText;
          }
        case 'email':
          final element = child.getElement('text');
          if (element != null) {
            email = element.innerText;
          }
        case 'gender':
          final element = child.getElement('sex')?.getElement('text');
          if (element != null) {
            gender = element.innerText;
          }
      }
    }

    return VCard4(
      fullname: fullname,
      uid: uid,
      surnames: surnames,
      username: usernames,
      photo: photo,
      binval: binval,
      bday: bday,
      email: email,
      gender: gender,
    );
  }

  /// Converts the `VCard4` instance to an XML element.
  @override
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();

    builder.element(
      name,
      attributes: <String, String>{'xmlns': namespace},
      nest: () {
        if (fullname?.isNotEmpty ?? false) {
          builder.element(
            'fn',
            nest: () =>
                builder.element('text', nest: () => builder.text(fullname!)),
          );
        }
        if (uid?.isNotEmpty ?? false) {
          builder.element(
            'uid',
            nest: () => builder.element('text', nest: () => builder.text(uid!)),
          );
        }
        if (surnames?.isNotEmpty ?? false) {
          builder.element(
            'n',
            nest: () {
              for (final surname in surnames!.entries) {
                builder.element(
                  surname.key,
                  nest: () => builder.text(surname.value),
                );
              }
            },
          );
        }
        if (username?.isNotEmpty ?? false) {
          for (final nick in username!) {
            builder.element(
              'nickname',
              nest: () =>
                  builder.element('text', nest: () => builder.text(nick)),
            );
          }
        }
        if (bday?.isNotEmpty ?? false) {
          builder.element(
            'bday',
            nest: () =>
                builder.element('date', nest: () => builder.text(bday!)),
          );
        }
        if (photo?.isNotEmpty ?? false) {
          builder.element(
            'photo',
            nest: () =>
                builder.element('uri', nest: () => builder.text(photo!)),
          );
        }
        if (binval?.isNotEmpty ?? false) {
          builder.element(
            'photo',
            nest: () =>
                builder.element('BINVAL', nest: () => builder.text(binval!)),
          );
        }
        if (email?.isNotEmpty ?? false) {
          builder.element(
            'email',
            nest: () =>
                builder.element('text', nest: () => builder.text(email!)),
          );
        }
        if (gender?.isNotEmpty ?? false) {
          builder.element(
            'gender',
            nest: () => builder.element(
              'sex',
              nest: () => builder.element(
                'text',
                nest: () => builder.text(gender!),
              ),
            ),
          );
        }
      },
    );

    return builder.buildDocument().rootElement;
  }

  /// The name of the XML element representing the vCard.
  @override
  String get name => 'vcard';

  /// The XML namespace for the vCard 4.0.
  @override
  String get namespace => 'urn:ietf:params:xml:ns:vcard-4.0';

  /// A tag used to identify the vCard element.
  @override
  String get tag => vCard4Tag;
}
