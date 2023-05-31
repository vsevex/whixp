# Echo

ECHO is a lightweight and pure Dart library that allows you to connect to XMPP (Extensible Messaging and Presence Protocol) servers. This package provides a range of fundamental functionalities for XMPP communication. And is built on top of the popular [Strophe.js](https://github.com/strophe/strophejs) library, providing a streamlined and efficient solution for XMPP communication in Dart applications.

## XMPP

XMPP is an open source standart protocol widely used for real-time communication, enabling features such as instant messaging, presence information, and contact list management. With this package, you can easily integrate XMPP capabilities into your Dart & Flutter applications, facilitating secure communication between users.

## Features

**Websocket Connectivity**:  Echo establishes connections to XMPP servers exclusively over the WebSocket protocol, ensuring efficient and reliable communication.

**Authentication Mechanisms**: Provides support for various XMPP authentication mechanisms, including **SASL SCRAM** with encryption options such as SHA-1, SHA-256, SHA-384, SHA-512, XOAUTH-2, OAUTHBEARER, Anonymous, and EXTERNAL.

> While support for these mechanisms are available, only SHA-1, PLAIN, and SHA-256 have been tested thoroughly.

**Fundamental Functionalities**: Echo provides a set of fundamental functionalities, including sending and retrieving messages, presence management, roster management, and more.

**Pure Dart implementation**: Written in pure Dart, enabling easy integration with Dart and Flutter projects.

**Lightweight**: Echo is designed to be lightweight, providing a streamlined solution for XMPP connectivity without unnecessary dependencies or overhead.

## Up-Coming Features

**BOSH**: At the moment, the package does not support BOSH (Bidirectional-streams Over Synchronous HTTP) connections, which provides an alternative method for connecting to the server. But in future updates, HTTP-binding will be enabled, stay tuned. (XEP-0124)

**vCard Support**: Which are used to represent and exchange personal information in XMPP. Later on, you can easily manage vCards for users, including creating, updating, retrieving, and deleting information.

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
