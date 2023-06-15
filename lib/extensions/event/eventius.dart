part of 'event.dart';

typedef EventiusListener<P> = void Function(P callback);
typedef ListenerFilter<P> = bool Function(P callback);
typedef ListenerKiller = void Function();

class Eventius<P> {
  Eventius({this.name = 'event'});

  /// The corresponding `event` name.
  final String name;

  /// The list of available listeners.
  final _listeners = <EventiusListener<P>>[];

  /// The available payload(s) queue.
  final _payloadsQueue = <P>[];

  /// [bool] indicator that resolves if some event is in action.
  bool _isBusy = false;

  /// The current listeners count.
  int get count => _listeners.length;

  /// Fires a null callback without using history.
  ///
  /// Uses [delay] to delay firing.
  void notify([Duration? delay]) => fire(null as P, delay: delay);

  /// Fire the payload for all listeners.
  ///
  /// Uses [delay] to delay firing.
  Future<void> fire(P payload, {Duration? delay}) async {
    /// Check if [delay] is not null, if it is not null then fire callback after
    /// [delay].
    if (delay != null) await Future.delayed(delay);

    /// Push provided value to the queue.
    _payloadsQueue.add(payload);

    loop();
  }

  /// Call all listeners with the provided payloads.
  void loop() {
    /// If current event is busy, then return.
    if (_isBusy) return;

    /// Set the current event in busy mode.
    _isBusy = true;

    /// Fire all payloads.
    while (_payloadsQueue.isNotEmpty) {
      final P currentPayload = _payloadsQueue.removeAt(0);
      for (final listener in _listeners) {
        listener(currentPayload);
      }
    }

    /// Equal current event to idle.
    _isBusy = false;
  }

  /// The same as [addListener] but will call listener only if `filter` returns
  /// `true`.
  ListenerKiller addFilteredListener(
    EventiusListener<P> listener,
    ListenerFilter<P> filter,
  ) =>
      addListener((payload) {
        if (filter(payload)) listener(payload);
      });

  /// Add [listener] to _listeners.
  ///
  /// * @return ListenerKiller as an alias for `remove(listener)`.
  ListenerKiller addListener(EventiusListener<P> listener) {
    /// Add `listener` to listeners list.
    _listeners.add(listener);

    return () => removeListener(listener);
  }

  /// Listens to another [Eventius] of the same type.
  ListenerKiller listenTo(Eventius<P> event, {Duration? delay}) =>
      event.addListener(
        (callback) => fire(
          callback,
          delay: delay,
        ),
      );

  /// Clear listeners list.
  ///
  /// Use [filter] to select which listener to be removed.
  void clear([bool Function(EventiusListener<P> listener)? filter]) =>
      filter != null ? _listeners.clear() : _listeners.removeWhere(filter!);

  /// Remove provided listener from the list of `listeners`.
  void removeListener(EventiusListener<P> listener) =>
      _listeners.remove(listener);

  /// Returns future that completes on next fire.
  ///
  /// `onNext(1)` completes after second fire because it ignore 1 fire.
  Future<P> onNext([int? ignoreCount]) async {
    final completer = Completer<P>();
    final killer = addListener((callback) {
      if ((ignoreCount ?? 0) <= 0) completer.complete(callback);
      ignoreCount = (ignoreCount ?? 0) - 1;
    });

    return completer.future.whenComplete(killer);
  }
}
