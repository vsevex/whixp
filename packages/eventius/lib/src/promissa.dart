import 'dart:async';

import 'package:events_emitter/events_emitter.dart';

typedef OnErrorCallback = void Function(dynamic reason);

Future<T> promise<T>(
  EventEmitter emitter,
  String event, {
  String? rejectEvent,
  int? timeout,
  OnErrorCallback? onError,
  void Function(T value)? onEvent,
}) {
  Timer? timer;

  void cleanup() {
    if (timer != null) {
      timer.cancel();
    }
    emitter.off(type: event, callback: onEvent);
    if (rejectEvent != null) {
      emitter.off(type: rejectEvent, callback: onError);
    }
  }

  Future<dynamic> onError(Object reason) {
    cleanup();
    return Future.error(reason);
  }

  Future<T> onEvent(T value) {
    cleanup();
    return Future.value(value);
  }

  emitter.once(event, onEvent);
  if (rejectEvent != null) {
    emitter.once(rejectEvent, onError);
  }

  if (timeout != null) {
    timer = Timer(Duration(milliseconds: timeout), () => cleanup());
  }

  return Future.value();
}
