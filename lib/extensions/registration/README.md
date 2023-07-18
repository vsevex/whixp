# Registration

This extension allows users to register new accounts on an XMPP server directly from the client (in this case Echo), streamlining the registration process. Provides accurate (not always) implementation of the **XEP-0077** (In-Band Registration) protocol.

## Features

- Implements corresponding protocol.
- Works efficiently with an association of the **ejabberd** server.
- Tested and supported for connection over WebSockets (not supported on some servers).
- Does not support BOSH connection as BOSH functionality is not implemented in this package.

## Problems

- Registration over WebSocket: The extension may not support registration over WebSocket on some servers due to server limitations. In such cases, it is recommended to use a different connection method.
- BOSH Support: The extension currently does not support BOSH connection and due to this problem (limitation), if BOSH functionality is required, consider exploring alternative solutions.
- Compatibility with Openfire Server: The extension has been primarily tested and verified for compatibility with ejabberd servers. Note: Users intending to use Openfire servers may encounter issues.

## Limitations

- **Pre-Connection**: As of now, this extension should be implemented and initialized with the client before connecting to the server. This is necessary because user details need to be entered into the registration fields (automatically) before initiating the connection.
- **Single Registration**: Users can only register once with the current implementation. After successful registration, users need to reconnect to the server without attaching the registration extension.

Please note that while the current version of the extension presents these limitations, future updates may address these issues and provide more flexible functionality.

## API

This code snippet demonstrates how to use this extension for the client.

```dart

import 'dart:developer';

import 'package:echo/echo.dart';

Future<void> main() async {
  final echo = Echo(service: 'ws://example.com:5443/ws');
  await echo.connect(
    jid: 'vsevex@example.com',
    password: 'randompasswordwhichisgoingtobeyourpassword',
    callback: (status) async {
      if (status == EchoStatus.register) {
        log('you can submit a form now');
        registration.submit(
          resultCallback: (_) {
            log('you are registered user now.');
            echo.disconnect('registered and disconnecting...');
          },
        );
      }
    },
  );
}

```
