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

For learning how to use [Whixp](https://github.com/vsevex/whixp), see its [documentation](https://whixp.dosy.app/).

## Visual demonstration

Below is a visual demonstration showcasing the real-world application of the Whixp package.

Watch the full demonstration here:

[Whixp in use.](https://dosybuck.s3.amazonaws.com/whixp/whixp.mp4)

## Features

**Connection Management**: Establishes secure connections to XMPP servers effortlessly. Manage connection states with ease: connect, disconnect, and handle reconnections properly.

**Stanza Handling**: Efficiently handles various XMPP stanzas, including IQ, message, and presence stanzas. You can customize stanza handling based on your application's requirements.

**Extensions Support**: Extensible architecture supports XMPP protocol extensions.

**Pure Dart implementation**: Written in pure Dart, enabling easy integration with Dart and Flutter projects.

**Lightweight**: Whixp is designed to be lightweight, providing a streamlined solution for XMPP connectivity without unnecessary dependencies or overhead.

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
