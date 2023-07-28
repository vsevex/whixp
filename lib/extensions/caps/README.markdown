# Entity Capabilities

This extension provides support for handling capabilities in the XMPP protocol using Caps (short for **Capabilities**) feature. Allows a client to advertise its capabilities to other entities and discover the capabilities of other entities in the XMPP network.

## Features

- Advertise and discover capabilities of XMPP entities.
- Efficiently handle capabilities updates to avoid unnecessary queries.
- Automatic capabilities exchange during XMPP connection establishment.

## Limitations

Please note that you need to use `echo.disco.addFeature` and `echo.disco.addIdentity` methods to add capabilities features and identity to the client. This extension does not provide built-in methods for adding features and identities to the disco extension.

## Embedding

This extension comes built-in to the client. It means you do not need to attach this extension as you did on other extensions. You can not disable or enable this feature in any way.

## API

This code snippet demonstrates how to use this extension for the client.

```dart

import 'dart:async';
import 'dart:developer';

import 'package:echo/echo.dart';

Future<void> main() async {
  final echo = Echo(service: 'ws://example.com:5443/ws');

  await echo.connect(
    jid: 'vsevex@example.com',
    password: 'randompasswordwhichisgoingtobeyourpassword',
    callback: (status) async {
      if (status == EchoStatus.connected) {
        log('Connection Established');
        echo.disco.addFeature('someFeature');
        echo.caps.sendPresence();
      } else if (status == EchoStatus.disconnected) {
        log('Connection Terminated');
      } else if (status == EchoStatus.register) {
        registrationCompleter.complete(true);
      }
    },
  );
}

```
