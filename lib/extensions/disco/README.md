# Service Discovery

XMPP server service discovery extension, providing enhanced functionality for discovering services within an XMPP network. The rest of doc provides a brief of the extension and its features.

**XEP-0030**: Is built upon the foundation of this protocol, which is a standard XMPP protocol extension. This protocol defines a mechanism for discovering information about services provided by XMPP entities. It allows clients and servers to discover various features, identities, and supported namespaces offered by XMPP entities.

## Key Features

- **Service Discovery**: This extension enables XMPP clients and servers to discover the available services within an XMPP network.
- **Global Availability**: This extension is attached by default for global use within the server.

## API

This code snippet demonstrates how to use this plugin for the client after establishing a connection using the `Echo` package.

```dart

import 'dart:developer';

import 'package:echo/echo.dart';

Future<void> main() async {
  final echo = Echo(service: 'ws://example.com:7070/ws');
  await echo.connect(
    jid: 'vsevex@example.com',
    password: 'somepsw',
    callback: (status) async {
      if (status == EchoStatus.connected) {
        log('Connection Established');
        echo.disco.info(
          'vsevex@example.com',
          onSuccess: (element) {
            log(element);
            /// ...outputs server information about enabled services.
          },
        );
      } else if (status == EchoStatus.disconnected) {
        log('Connection Terminated');
      }
    },
  );
}

```
