# Eventius

The `eventius` library provides classes and utilities for event management and listener registration in Dart based applications.

This library introduces `Eventius` class, which serves as an event manager that allows you to handle events, manage listeners, and maintain event history. Additionally, it defines related typedefs and utility to simplify event management tasks.

## Usage

```dart

import 'dart:developer';

import 'package:event/event.dart';

void main() {
  final eventius = Eventius<String>(name: 'example');
  final payloads = <String>[];
  final objectPayloads = <String>[];

  eventius.addListener((payload) {
    payloads.add(payload);
  });
  eventius.fire('hert');

  final eventObject = Example();
  eventObject.on((payload) => objectPayloads.add(payload));
  eventObject.fire('hert');

  log('payloads: $payloads\nobjectPayloads: $objectPayloads');
}

class Example extends EventObject<String> {}

```

## Features

- Add listeners to handle events.
- Fire events with associated payloads.
- Maintain event history with customizable limits.
- Create links between different event managers.
- Establish listening connections to capture events from other managers.
