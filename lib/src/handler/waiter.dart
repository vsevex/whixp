import 'dart:async';

import 'package:synchronized/extension.dart';

import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/stream/base.dart';

class Waiter extends Handler {
  Waiter(super.name, {required super.matcher, super.transport});

  final completer = Completer<StanzaBase?>();

  @override
  FutureOr<void> run(StanzaBase payload) {
    if (!completer.isCompleted) {
      completer.complete(payload);
    }
  }

  /// Blocks an event handler while waiting for a stanza to arrive.
  ///
  /// [timeout] is represented in seconds.
  Future<StanzaBase?> wait({int timeout = 10}) async {
    if (transport == null) {
      throw Exception('wait() called without a transport');
    }

    try {
      await synchronized(() => completer.future).timeout(
        Duration(seconds: timeout),
        onTimeout: () {
          completer.complete();
          throw TimeoutException('Timed out waiting for $name');
        },
      );
    } on TimeoutException {
      if (transport != null) {
        transport!.removeHandler(name);
      }
    }

    return completer.future;
  }
}
