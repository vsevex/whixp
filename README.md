# Echo

![Github last build (main)][last_build]
[![License: MIT][license_badge]][license_link]
![GitHub Repo stars][star_count]
![GitHub last commit (main)][last_commit]

Echo is a lightweight and pure Dart library that allows you to connect to XMPP (Extensible Messaging and Presence Protocol) servers. This package provides a range of fundamental functionalities for XMPP communication. And is built on top of the popular [Strophe.js](https://github.com/strophe/strophejs) library, providing a streamlined and efficient solution for XMPP communication in Dart applications.

## XMPP

XMPP is an open source standart protocol widely used for real-time communication, enabling features such as instant messaging, presence information, and contact list management. With this package, you can easily integrate XMPP capabilities into your Dart & Flutter applications, facilitating secure communication between users.

## Features

**WebSocket Connectivity**: Echo establishes connections to XMPP servers exclusively over the WebSocket protocol, ensuring efficient and reliable communication.

**Authentication Mechanisms**: Provides support for various XMPP authentication mechanisms, including **SASL SCRAM** with encryption options such as SHA-1, SHA-256, SHA-384, SHA-512, XOAUTH-2, OAUTHBEARER, Anonymous, and EXTERNAL.

> While support for these mechanisms are available, only SHA-1, PLAIN, and SHA-256 have been tested thoroughly.

**Fundamental Functionalities**: Echo provides a set of fundamental functionalities, including sending and retrieving messages, presence management, roster management, and more.

**Pure Dart implementation**: Written in pure Dart, enabling easy integration with Dart and Flutter projects.

**Lightweight**: Echo is designed to be lightweight, providing a streamlined solution for XMPP connectivity without unnecessary dependencies or overhead.

## Supported Extensions

**V-Card**: (XEP-0054) The vCard extension in the XMPP server refers to a feature that allows users to create and manage virtual business cards within the XMPP communication protocol.
For more information please navigate to `lib/extensions/v-card/`.

**Publish-Subscribe**: (XEP-0060, XEP-0248) The Pubsub (Publish-Subscribe) extension in XMPP server support is a feature that enables the distribution and dissemination of published information to interested subscribers within the XMPP network. It is a key component of the XMPP protocol for building real-time messaging and notification systems.

**Disco**: (XEP-0030) The Service Discovery extension provides enhanced functionality for discovering services within an XMPP network. The rest of doc provides a brief of the extension and its features.

**Registration**: (XEP-0077) The registration extension allows users to register new accounts on an XMPP server directly from the client, streamlining the registration process.

**Roster Versioning**: (XEP-0237) The roster versioning extension allows for enhanced management of contact lists, including group-based rostering and improved roster synchronization in XMPP communication.

## Up-Coming Features

**Isolated WebSosket(s)** This isolation allows for focused and dedicated WebSocket connectivity, enabling efficient and reliable real-time communication between the client and the XMPP server.

## API

This code snippet demonstrates how to establish a connection using the `Echo` package.

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
        /// ...do whatever you need.
        log('Connection Established');
      } else if (status == EchoStatus.disconnected) {
        log('Connection Terminated');
      }
    },
  );
}

```

`Echo` also provides a set of utility methods to simplify common tasks in XMPP communication. Here is an example of how to use the `Echotils`.

```dart

import 'dart:developer';

import 'package:echo/echo.dart';

void main()  {
  const jid = 'vsevex@localhost';
  final domain = Echotils().getDomainFromJID(jid);

  log(domain); /// output: localhost
}

```

## Contributing to Echo

We welcome and appreciate contributions from the community to enhance the `Echo`. If you have any improvements, bug fixes, or new features to contribute, you can do so by creating a pull request.

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[star_count]: https://img.shields.io/github/stars/vsevex/echo
[last_commit]: https://img.shields.io/github/last-commit/vsevex/echo/main
[last_build]: https://img.shields.io/github/actions/workflow/status/vsevex/echo/dart.yml
