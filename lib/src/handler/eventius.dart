import 'dart:async';

typedef RemoveListener = void Function();

abstract class _Eventius {
  late final _events = <String, List<FutureOr<void> Function<B>([B?])>>{};

  RemoveListener on(
    String event,
    FutureOr<void> Function<B>([B? data]) handler,
  );

  void once(String event, FutureOr<void> Function<B>([B? data]) handler);

  FutureOr<void> emit<B>(String event);

  void off(String event);

  void clear();
}

class Eventius extends _Eventius {
  @override
  RemoveListener on(
    String event,
    FutureOr<void> Function<B>([B? data]) handler,
  ) {
    final eventContainer = _events.putIfAbsent(
      event,
      () => <FutureOr<void> Function<B>([B?])>[],
    );

    void offThislistener() => eventContainer.remove(handler);

    eventContainer.add(handler);

    return () => offThislistener();
  }

  @override
  void once(String event, FutureOr<void> Function<B>([B? data]) handler) {
    final eventContainer =
        _events.putIfAbsent(event, () => <FutureOr<void> Function<B>([B?])>[]);
    eventContainer.add(<B>([B? data]) async {
      await handler(data);
      off(event);
    });
  }

  @override
  FutureOr<void> emit<B>(String event, [B? data]) async {
    final eventContainer = _events[event] ?? [];
    for (final event in eventContainer) {
      await event(data);
    }
  }

  @override
  void off(String event) => _events.remove(event);

  @override
  void clear() => _events.clear();

  Map<String, List<FutureOr>> get events => _events;
}
