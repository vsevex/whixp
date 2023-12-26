import 'dart:async';

typedef RemoveListener = void Function();

abstract class _Eventius {
  late final _events = <String, List<FutureOr<Function>>>{};

  RemoveListener on<A, B>(
    String event,
    FutureOr<A> Function([B? data]) handler,
  );

  void once<A, B>(String event, FutureOr<A> Function([B? data]) handler);

  void emit<B>(String event, [B? data]);

  void off(String event);

  void clear();
}

class Eventius extends _Eventius {
  @override
  RemoveListener on<A, B>(
    String event,
    FutureOr<A> Function([B? data]) handler,
  ) {
    final eventContainer = _events.putIfAbsent(
      event,
      () => List<FutureOr<A> Function([B])>.empty(),
    );

    void offThislistener() => eventContainer.remove(handler);

    eventContainer.add(handler);

    return () => offThislistener();
  }

  @override
  void once<A, B>(String event, FutureOr<A> Function([B? data]) handler) {
    final eventContainer = _events.putIfAbsent(
      event,
      () => List<FutureOr<A> Function([B])>.empty(),
    );
    eventContainer.add((B? data) {
      handler(data);
      off(event);
    });
  }

  @override
  void emit<B>(String event, [B? data]) {}

  @override
  void off(String event) => _events.remove(event);

  @override
  void clear() => _events.clear();

  Map<String, List<FutureOr<Function>>> get events => _events;
}
