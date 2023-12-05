import 'dart:async';

import 'package:echox/src/handler/handler.dart';
import 'package:echox/src/stream/base.dart';

class CallbackHandler extends Handler {
  CallbackHandler(super.name, {required super.matcher});

  @override
  void prerun(StanzaBase payload) {
    // TODO: implement prerun
  }

  @override
  void run(StanzaBase payload) {
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
  final future = Completer<dynamic>();

  /// Indicates if the callback should be executed during stream processing.
  final bool instream;

  @override
  void prerun(StanzaBase payload) {
    if (once) {
      destroy = true;
    }

    run(payload, instream: instream);
  }

  @override
  void run(StanzaBase payload, {bool instream = false}) {
    if (!this.instream || instream) {
      future.complete(callback(payload));
    }
    if (once) {
      destroy = true;
    }
  }
}
