# Whixp

![Github last build (main)][last_build]
[![License: MIT][license_badge]][license_link]
![GitHub Repo stars][star_count]

<div align="center">
    <img alt="whixp" src="https://dosybuck.s3.amazonaws.com/whixp/whixp_dark.svg">
</div>

## Introduction

Welcome to Whixp (**/wɪksp/**)!

Whixp is a lightweight and pure Dart library that allows you to connect to XMPP (Extensible Messaging and Presence Protocol) servers.

For learning how to use [Whixp](https://github.com/vsevex/whixp), see its [documentation](https://dosyllc.github.io/whixpdoc/).

Below is a visual demonstration showcasing the real-world application of the Whixp package.

[Whixp in use](https://dosybuck.s3.amazonaws.com/whixp/whixp.mp4).

## Why Use Whixp?

**🏗️ Built for Dart & Flutter**: Whixp is written in pure Dart, making it the perfect choice for Dart and Flutter applications. No platform-specific code, no web compatibility compromises—just clean, native Dart that works seamlessly across Android, iOS, macOS, and Windows.

**🚀 Production-Ready**: With comprehensive XMPP protocol support including Stream Management (XEP-0198), Message Archive Management (XEP-0313), Chat Markers (XEP-0333), and more, Whixp provides everything you need to build robust XMPP clients.

**🔌 Extensible Architecture**: Whixp's plugin-based architecture makes it easy to add new XMPP protocol extensions. The well-designed plugin system allows you to extend functionality without modifying core code.

**⚡ Lightweight & Performant**: Designed with performance in mind, Whixp avoids unnecessary dependencies and overhead. It's optimized for mobile and desktop applications where resource efficiency matters.

**🛡️ Reliable Connection Management**: Built-in reconnection policies, stream management, and robust error handling ensure your XMPP connections stay stable even in challenging network conditions.

**📱 Mobile-First**: Unlike web-focused XMPP libraries, Whixp is designed specifically for native mobile and desktop applications. It leverages Dart's strengths without the constraints of web platform limitations.

**🔒 Secure by Default**: Supports TLS/SSL encryption, SASL authentication mechanisms (SCRAM-SHA-1, SCRAM-SHA-256, PLAIN), and follows XMPP security best practices.

**🎯 Modern XMPP Features**: Supports modern XMPP extensions like MAM (message archiving), Chat Markers (read receipts), Unique Stanza IDs, and more—everything you need for a modern messaging experience.

**📚 Well-Documented**: Comprehensive documentation and examples help you get started quickly and implement advanced features with confidence.

**🤝 Actively Maintained**: Regular updates, bug fixes, and new feature additions ensure Whixp stays current with XMPP protocol developments.

## Features

**Connection Management**: Establishes secure connections to XMPP servers effortlessly. Manage connection states with ease: connect, disconnect, and handle reconnections properly.

**Stanza Handling**: Efficiently handles various XMPP stanzas, including IQ, message, and presence stanzas. You can customize stanza handling based on your application's requirements.

**Extensions Support**: Extensible architecture supports XMPP protocol extensions including:

- Stream Management (XEP-0198)
- Message Archive Management (XEP-0313)
- Chat Markers (XEP-0333)
- Unique Stanza IDs (XEP-0359)
- Service Discovery (XEP-0030)
- PubSub (XEP-0060)
- And more...

**Pure Dart Implementation**: Written in pure Dart, enabling easy integration with Dart and Flutter projects. **Note**: Web platform is not supported—Whixp is optimized for native mobile and desktop applications.

**Lightweight**: Whixp is designed to be lightweight, providing a streamlined solution for XMPP connectivity without unnecessary dependencies or overhead.

**Platform Support**:

- ✅ Android
- ✅ iOS
- ✅ macOS
- ✅ Windows
- ❌ Web (not supported - see [Limitations](#limitations))

## Limitations

**Web Platform**: Whixp does not support web platforms due to Dart/Flutter limitations with web sockets and native networking APIs. For web applications, consider using web-specific XMPP libraries.

**End-to-End Encryption**: OMEMO (XEP-0384) is not currently supported due to cryptographic library limitations in Dart. Basic TLS/SSL encryption and SASL authentication are fully supported.

**Native transport**: The optional Rust transport (TLS, WebSocket) ships as platform-specific binaries. How you get them: if the package on pub.dev includes them, `pub get` is enough; otherwise see [Getting the native libraries](native/README.md#how-users-get-the-binaries-after-pub-get) (download from [Releases](https://github.com/vsevex/whixp/releases) or build from source with `make`).

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
