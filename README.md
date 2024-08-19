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

**[Data Forms (XEP-0004)](https://xmpp.org/extensions/xep-0004.html)**: Allows for the exchange of structured data, often used for service configuration and reporting.

**[Publish-Subscribe (PubSub) (XEP-0060)](https://xmpp.org/extensions/xep-0060.html)**: Facilitates a publish-subscribe messaging pattern, distributing information to interested parties efficiently.

**[Stream Management (XEP-0198)](https://xmpp.org/extensions/xep-0198.html)**: Enhances connection reliability with features like message acknowledgment and session resumption, supporting offline storage.

**[vCard4 over PubSub (XEP-0292)](https://xmpp.org/extensions/xep-0292.html)**: Enables sharing and retrieving profile information like name and email in a structured format using PubSub.

**[Message Archive Management (XEP-0313)](https://xmpp.org/extensions/xep-0313.html)**: Allows servers to store and retrieve archived messages for improved user experience and data continuity.

**[Push Notifications (XEP-0357)](https://xmpp.org/extensions/xep-0357.html)**: Integrates push notification support for real-time communication systems.

These extensions provide a robust foundation for advanced XMPP functionalities, ensuring Whixp is suitable for various real-time communication needs.

> Explore the examples provided to understand how to use these extensions, including messaging, PubSub, and stream management.

## API

This code snippet demonstrates how to establish a connection using the `Whixp` package.

```dart
import 'package:whixp/whixp.dart';

void main() {
  final whixp = Whixp(
    jabberID: 'vsevex@localhost/resource',
    password: 'passwd',
    host: 'localhost',
    logger: Log(enableWarning: true, enableError: true, includeTimestamp: true),
    reconnectionPolicy: RandomBackoffReconnectionPolicy(0, 2),
  );

  whixp.addEventHandler('streamNegotiated', (_) => whixp.sendPresence());
  whixp.connect();
}
```

## Contributing to Whixp

I welcome and appreciate contributions from the community to enhance `Whixp`. Here’s how you can get involved:

1. Bug Reports and Feature Requests: If you encounter any issues or have ideas for new features, feel free to open an issue on the [GitHub repository](https://github.com/vsevex/whixp/issues). Provide as much detail as possible to help us address your concerns effectively.
2. Pull Requests: If you have a fix or a new feature, you can create a pull request. Ensure your code adheres to the coding standards, includes relevant tests, and is well-documented. We encourage you to discuss major changes in an issue before starting to work on them.
3. Documentation: Improving and expanding the documentation is a great way to contribute. Whether it’s correcting typos, clarifying instructions, or adding new examples, every contribution helps!
4. Testing: Help me ensure Whixp’s reliability by writing and running tests. Contributing to test suite or reporting test results for different environments strengthens the project for everyone.
5. Spread the Word: If you find Whixp useful, consider sharing it with your peers. Writing blog posts, speaking at events, or creating tutorials can help others discover and utilize `Whixp`.

Thank you for helping make Whixp better for everyone!

[license_badge]: https://img.shields.io/badge/license-MIT-blue.svg
[license_link]: https://opensource.org/licenses/MIT
[star_count]: https://img.shields.io/github/stars/vsevex/whixp
[last_build]: https://img.shields.io/github/actions/workflow/status/vsevex/whixp/dart.yml
