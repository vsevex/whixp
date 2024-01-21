# Whixp

![Github last build (main)][last_build]
[![License: MIT][license_badge]][license_link]
![GitHub Repo stars][star_count]

<div align="center">
    <img alt="whixp" src="https://raw.githubusercontent.com/vsevex/whixp/45439a108689b831c39beefa8c98c563f50e3d4f/assets/whixp_dark.svg">
</div>

Whixp is a lightweight and pure Dart library that allows you to connect to XMPP (Extensible Messaging and Presence Protocol) servers. This package provides a range of fundamental functionalities for XMPP communication.

## XMPP

XMPP is an open source standart protocol widely used for real-time communication, enabling features such as instant messaging, presence information, and contact list management.

With this package, you can easily integrate XMPP capabilities into your Dart & Flutter applications, facilitating secure communication between users.

## Features

**Connection Management**: Establishes secure connections to XMPP servers effortlessly. Manage connection states with ease: connect, disconnect, and handle reconnections properly.

**Stanzas Handling**: Efficiently handles various XMPP stanzas, including IQ, message, and presence stanzas. You can customize stanza handling based on your application's requirements.

**Extensions Support**: Extensible architecture supports XMPP protocol extensions.

**Authentication Mechanisms**: Provides support for various XMPP authentication mechanisms, including **SASL SCRAM** with encryption options such as SHA-1, SHA-256, SHA-384, SHA-512, PLAIN and ANONYMOUS.

> While support for these mechanisms are available, only SHA-1, SHA-256, PLAIN, and ANONYMOUS have been tested thoroughly.

**Pluggable Architecture**: Build on top of a modular and pluggable architecture. You can easily extend and customize Whixp to fit your specific use case.

**Fundamental Functionalities**: Whixp provides a set of fundamental functionalities, including sending and retrieving messages, presence management, roster management, and more.

**Pure Dart implementation**: Written in pure Dart, enabling easy integration with Dart and Flutter projects.

**Lightweight**: Whixp is designed to be lightweight, providing a streamlined solution for XMPP connectivity without unnecessary dependencies or overhead.

## Available Plugins

**DataForms**: Providing a mechanism for exchanging complex data.

**Disco**: Discovers information about entities and services.

**Result Set Management**: Provides reliable stanza delivery.

**PubSub**: Enables publish-subscribe messaging.

**Ping**: Checks the connection status of another entity.

**Date and Time Profiles**: Negotiates the format of date and time information.

**Delay**: Delays the delivery of stanzas.

## API

This code snippet demonstrates how to establish a connection using the `Whixp` package.

```dart
import 'package:whixp/whixp.dart';

void main() {
  final whixp = Whixp(
    'vsevex@example.com/desktop',
    'passwd',
    host: 'example.com',
    logger: Log(enableError: true, enableWarning: true),
  );

  whixp.connect();
  whixp.addEventHandler('sessionStart', (_) {
    whixp.getRoster();
    whixp.sendPresence();
  });
}
```

## Contributing to Whixp

I do welcome and appreciate contributions from the community to enhance the `Whixp`. If you have any improvements, bug fixes, or new features to contribute, you can do so by creating a pull request.

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[star_count]: https://img.shields.io/github/stars/vsevex/whixp
[last_build]: https://img.shields.io/github/actions/workflow/status/vsevex/whixp/dart.yml
