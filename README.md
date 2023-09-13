# EchoX

![EchoX Logo][logo]
![Github last build (main)][last_build]
[![License: MIT][license_badge]][license_link]
![GitHub Repo stars][star_count]

EchoX is a lightweight and pure Dart library that allows you to connect to XMPP (Extensible Messaging and Presence Protocol) servers. This package provides a range of fundamental functionalities for XMPP communication. And is built on top of the popular [Strophe.js](https://github.com/strophe/strophejs) library, providing a streamlined and efficient solution for XMPP communication in Dart applications.

## XMPP

XMPP is an open source standart protocol widely used for real-time communication, enabling features such as instant messaging, presence information, and contact list management. With this package, you can easily integrate XMPP capabilities into your Dart & Flutter applications, facilitating secure communication between users.

## Features

**WebSocket Connectivity**: EchoX establishes connections to XMPP servers exclusively over the WebSocket protocol, ensuring efficient and reliable communication.

**Authentication Mechanisms**: Provides support for various XMPP authentication mechanisms, including **SASL SCRAM** with encryption options such as SHA-1, SHA-256, SHA-384, SHA-512, XOAUTH-2, OAUTHBEARER, Anonymous, and EXTERNAL.

> While support for these mechanisms are available, only SHA-1, PLAIN, and SHA-256 have been tested thoroughly.

**Fundamental Functionalities**: EchoX provides a set of fundamental functionalities, including sending and retrieving messages, presence management, roster management, and more.

**Pure Dart implementation**: Written in pure Dart, enabling easy integration with Dart and Flutter projects.

**Lightweight**: EchoX is designed to be lightweight, providing a streamlined solution for XMPP connectivity without unnecessary dependencies or overhead.

## API

This code snippet demonstrates how to establish a connection using the `EchoX` package.

```dart
import 'package:echox/echox.dart';

void main() async {
  final echox = EchoX(
    service: 'ws://example.com:port/ws',
    jid: JabberID(
      'user',
      domain: 'localhost',
      resource: 'mobile',
    ),
    password: 'somepsw',
  );

  debug(echox);
  echox.connect();
}

```

## Contributing to EchoX

We welcome and appreciate contributions from the community to enhance the `EchoX`. If you have any improvements, bug fixes, or new features to contribute, you can do so by creating a pull request.

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[star_count]: https://img.shields.io/github/stars/vsevex/echox
[last_build]: https://img.shields.io/github/actions/workflow/status/vsevex/echox/dart.yml
[logo]: https://raw.githubusercontent.com/vsevex/echox/main/assets/echox.svg
