# V-Card

The vCard plugin enables users to attach additional information to their XMPP profiles, such as their full `name`, `nickname`, `avatar`, `job title`, contact details, and other personal or professional details. It serves as a digital representation of an individual or an entity's contact information.

Key features and benefits of the vCard plugin in XMPP server support include:

- Profile Information: Users can create and maintain their personal profiles, providing detailed information about themselves, such as their name, organization, job title, email address, phone number, and other relevant data.
- Avatars: The plugin allows users to upload and display profile pictures or avatars, making it easier to visually identify individuals within the XMPP network.
- Contact Sharing: Users can exchange and share their vCards with other users, allowing them to quickly access and import contact information into their own address books or client applications.

## API

This code snippet demonstrates how to attach this plugin to the client after establishing a connection using the `Echo` package.

```dart

import 'dart:developer';

import 'package:echo/echo.dart';

Future<void> main() async {
  final echo = Echo(service: 'ws://localhost:7070/ws');
  await echo.connect(
    jid: 'vsevex',
    password: 'somepassw',
    callback: (status) async {
      if (status == EchoStatus.connected) {
        log('Connection Established');
        final vCard = VCardExtension();
        echo.attachExtension(vCard);
        /// ...do whatever you need with the extension.
      } else if (status == EchoStatus.disconnected) {
        log('Connection Terminated');
      }
    },
  );
}

```
