import 'dart:async';

import 'package:echox/src/handler/handler.dart';
import 'package:echox/src/stream/base.dart';

import 'package:synchronized/synchronized.dart';

class CallbackHandler extends Handler {
  CallbackHandler(super.name, {required super.matcher});

  @override
  Future<void> prerun(StanzaBase payload) async {
    // TODO: implement prerun
  }

  @override
  Future<void> run(StanzaBase payload) async {
    // TODO: implement run
  }
}

class FutureCallbackHandler extends Handler {
  FutureCallbackHandler(
    super.name,
    this.callback, {
    required super.matcher,
    super.transport,
    this.once = false,
    this.instream = false,
  });

  final Future<void> Function(StanzaBase stanza) callback;
  final bool once;
  final _lock = Lock();

  /// Indicates if the callback should be executed during stream processing.
  final bool instream;

  @override
  Future<void> prerun(StanzaBase payload) async {
    print('prerun is called');
    if (once) {
      destroy = true;
    }
    if (instream) {
      await run(payload, instream: true);
    }
  }

  @override
  Future<void> run(StanzaBase payload, {bool instream = false}) async {
    print('run is called: $payload');
    if (!this.instream || instream) {
      await _lock.synchronized(() => callback(payload));
    }
    if (once) {
      destroy = true;
    }
  }
}
