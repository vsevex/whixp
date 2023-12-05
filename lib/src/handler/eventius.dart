import 'dart:async';

import 'package:events_emitter/events_emitter.dart';

class Eventius {
  Eventius([EventEmitter? emitter]) {
    _emitter = emitter ?? EventEmitter();
  }

  late final EventEmitter _emitter;

  EventListener<T?> createListener<T>(
    String event,
    FutureOr<dynamic> Function(T? data) callback, {
    bool disposable = false,
  }) =>
      EventListener<T?>(event, callback, once: disposable);

  void addEvent<E>(EventListener<E?> listener) =>
      _emitter.addEventListener<E?>(listener);

  void removeEventHandler<T>({String? event, EventListener<T?>? listener}) {
    if (event != null) {
      _emitter.off<T?>(type: event);
      return;
    } else if (listener != null) {
      _emitter.removeEventListener<T?>(listener);
    }
  }

  void emit<T>(String event, [T? data]) => _emitter.emit<T?>(event, data);
}
