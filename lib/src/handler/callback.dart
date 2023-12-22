import 'dart:async';

import 'package:echox/src/handler/handler.dart';
import 'package:echox/src/stream/base.dart';

class CallbackHandler extends Handler {
  CallbackHandler(super.name, this.callback, {required super.matcher});

  void Function(StanzaBase stanza) callback;

  @override
  void run(StanzaBase stanza) => callback.call(stanza);
}

class FutureCallbackHandler extends Handler {
  FutureCallbackHandler(super.name, this.callback, {required super.matcher});

  final Future<void> Function(StanzaBase stanza) callback;

  @override
  Future<void> run(StanzaBase payload) => callback(payload);
}
