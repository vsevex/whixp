import 'dart:async';

typedef _RemoveListener = void Function();

typedef _Handler<B> = FutureOr<void> Function(B? data);

abstract class _Eventius {
  late final _events = <String, List<dynamic>>{};

  _RemoveListener on<B>(String event, _Handler handler);

  void once<A>(String event, _Handler handler);

  FutureOr<void> emit<B>(String event, [B? data]);

  void off(String event);

  void clear();
}

class Eventius extends _Eventius {
  @override
  _RemoveListener on<B>(String event, _Handler<B> handler) {
    final List<_Handler<B>> handlerContainer =
        _events.putIfAbsent(event, () => <_Handler<B>>[]) as List<_Handler<B>>;

    void offThislistener() => handlerContainer.remove(handler);

    handlerContainer.add(handler);

    return () => offThislistener();
  }

  @override
  void once<A>(String event, _Handler<A> handler) {
    final handlerContainer = _events.putIfAbsent(event, () => <_Handler<A>>[]);
    handlerContainer.add(
      (A? data) async {
        if (handler is Future) {
          await handler(data);
        } else {
          handler(data);
        }
        off(event);
      },
    );
  }

  @override
  FutureOr<void> emit<B>(String event, [B? data]) async {
    final List<_Handler<B>> handlerContainer =
        (_events[event] as List<_Handler<B>>?) ?? [];
    for (final handler in handlerContainer) {
      if (handler is Future) {
        await handler(data);
      } else {
        handler(data);
      }
    }
  }

  @override
  void off(String event) => _events.remove(event);

  @override
  void clear() => _events.clear();

  Map<String, List<FutureOr>> get events => _events;
}
