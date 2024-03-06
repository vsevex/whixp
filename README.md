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

**Stanza Handling**: Efficiently handles various XMPP stanzas, including IQ, message, and presence stanzas. You can customize stanza handling based on your application's requirements.

**Extensions Support**: Extensible architecture supports XMPP protocol extensions.

**Authentication Mechanisms**: Provides support for various XMPP authentication mechanisms, including **SASL SCRAM** with encryption options such as SHA-1, SHA-256, SHA-384, SHA-512, PLAIN and ANONYMOUS.

**Pluggable Architecture**: Build on top of a modular and pluggable architecture. You can easily extend and customize Whixp to fit your specific use case.

**Fundamental Functionalities**: Whixp provides a set of fundamental functionalities, including sending and retrieving messages, presence management, roster management, and more.

**Pure Dart implementation**: Written in pure Dart, enabling easy integration with Dart and Flutter projects.

**Lightweight**: Whixp is designed to be lightweight, providing a streamlined solution for XMPP connectivity without unnecessary dependencies or overhead.

## Supported Protocol Extensions

**Data Forms**: Extension that enables the exchange of structured data between entities. It provides a flexible way to collect, configure, and report information using forms.
The main purpose of this extension is to collect user input for various purposes like service configuration or application-specific data gathering.

**Service Discovery**: Helps applications in a network environment automatically locate and interact with other services.
Enables applications to refer to services by logical names instead of physical addresses, simplifying configuration and improving flexibility.

**vcard-temp**: It is a legacy method for exchanging basic contact information between users. Enables users to share and retrieve basic profile information like name, nickname, email address, and physical address.

**Publish-Subscribe**: It is a powerful extension that facilitates a messaging pattern known as publish-subscribe. Efficiently distributes information to interested parties, reducing server load compared to direct messaging.

**In-Band Registration**: Helps to register accounts directly with an XMPP server. Enables creating new accounts by sending (username, password, etc.) to the server within the stream.

**Personal Eventing Protocol**: It is a simplified approach to using the pubsub (publish-subscribe) functionality of XMPP for broadcasting personal events associated with an account.
Enables users to share information about their status or activities with other interested users.

**Stream Management**: Enhances the reliability and user experience of XMPP connections by offering features like message acknowledgment and session resumption. Ensures messages are delivered and not lost due to network issues.

This list highlights some of the fundamental extensions supported by `whixp`, including functionality such as presence, messaging, and service discovery. But that is not all!
I've got you covered for more immersive experiences with extensions such as tune (sharing what you are listening to), ping, date and time profiles, and more.

> You can find several examples that demonstrate the usage by covering messaging, pubsub, components and how to use them, stream management, vcard retrieval, and publishing.

## XMPP Components

Components are a key feature of the XMPP protocol. A component is an external entity that connects to an XMPP server, extending its functionality and enabling additional services.
These components act as separate entities that can communicate with the XMPP server to provide specific features or services.
For instance, using an XMPP component as a proxy service between an XMP server and a push notification service (following XEP-0357) is a common scenario in real-time communication systems.

Whixp now gives you the ability to use XMPP components and start a component service that can support your project in a great manner.

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
  whixp.addEventHandler('streamNegotiated', (_) {
    whixp.getRoster();
    whixp.sendPresence();
  });
}
```

## More Use Cases

Several examples are provided to demonstrate usages, including messaging, pubsub, components (server-to-server communication) and how to utilize them, stream management, vCard retrieval, and publishing.
These examples offer comprehensive insights into several areas of the system, showcasing practical applications and highlighting the flexibility of messaging, pubsub, components, stream management, vCard retrieval, and publishing functions.

By exploring these examples, you can gain a deeper understanding of the intricacies involved in each feature and how to effectively integrate them into your projects.

## Contributing to Whixp

I do welcome and appreciate contributions from the community to enhance the `Whixp`. If you have any improvements, bug fixes, or new features to contribute, you can do so by creating a pull request.

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[star_count]: https://img.shields.io/github/stars/vsevex/whixp
[last_build]: https://img.shields.io/github/actions/workflow/status/vsevex/whixp/dart.yml
