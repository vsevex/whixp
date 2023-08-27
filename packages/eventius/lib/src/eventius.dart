import 'dart:async';

/// Represents a listener function for events.
///
/// Takes a single parameter of type [C] representing the payload associated
/// with an event. This listener is typically used to handle and react to events
/// triggered by an [Eventius] instance.
///
/// The [payload] parameter can be `null` if no payload is associated with the
/// event. The listener should process the event or payload as needed.
typedef EventiusListener<C> = void Function(C payload);

/// Represents a function to remove a listener.
///
/// When this listener is invoked, removed a listener associated with an
/// [Eventius] instance.
typedef ListenerKiller<C> = void Function();

/// Represents a function that filters event payloads.
///
/// Returns a [bool] value indicating whether the event payload should be
/// processed or filtered out.
typedef FilteredListener<C> = bool Function(C payload);

/// Represents a function to convert event payloads.
///
/// Performs a conversion and returns a value of type [R], which represents the
/// transformed result of the original payload.
typedef PayloadConverter<C, R> = R Function(C payload);

/// A class represents an event management system.
///
/// Provides a mechanism to manage events and event listeners. It allows you to
/// add listeners, fire events, and link events between instances. Events can
/// have associated payloads, and listeners can respond to events based on their
/// specific requirements.
///
/// ```dart
/// final eventius = Eventius<String>[];
///
/// eventius.addListener((payload) {
///   log('event received with payload: $payload');
/// });
///
/// eventius.fire('blya!');
/// ```
class Eventius<P> {
  /// Creates a new [Eventius] object whose default [name] is `eventius` and
  /// [historyLimit] is `-1`.
  Eventius({this.name = 'eventius', this.historyLimit = -1});

  /// The name of the event management system.
  final String name;

  /// The maximum number of events to retain in the history.
  ///
  /// If set to `0`, no history limit is imposed. If set to `-1`, then no
  /// history is saved.
  final int historyLimit;

  final _history = <P>[];
  final _payloadsQueue = <P>[];
  final _listeners = <EventiusListener<P>>[];
  final _onceListeners = <EventiusListener<P>>[];

  /// External [List] that keeps the listeners to be removed which is added
  /// through `once` method.
  final _listenerToRemove = <EventiusListener<P>>[];

  /// [bool] indicator to keep payload invocation busy if there is a running
  /// one.
  bool _isBusy = false;

  /// Returns the current history length to the user.
  int get historySize => _history.length;

  /// If payload history is not empty, then returns the last item of the current
  /// [history] list.
  P? get lastPayload => _history.isNotEmpty ? _history.last : null;

  /// Returns list of historical event payloads.
  ///
  /// The [history] method provides access to a list of historical event
  /// payloads. Returned list contains events that has been fired using the
  /// `fire` method. The size of the list is determined by the [historyLimit]
  /// set during the [Eventius] instsance`s creation.
  ///
  /// If no history limit was set or the limit is `0`, the list may contain all
  /// historical events recorded by the instance.
  List<P> get history => List.unmodifiable(_history);

  /// Fires an event with the given [payload].
  ///
  /// Synchronously calls each of the listeners registered for the event named
  /// `name`, in the order they were registered, passing the supplied arguments
  /// to each. The event [payload] can be controlled whether to be added to the
  /// historical record or not by the parameter of [useHistory].
  ///
  /// Optionally, [delay] can be introduced before firing the event. This can be
  /// useful to simulate asynchronous event propagation.
  ///
  /// ### Example:
  /// ```dart
  /// final eventius = Eventius<String>[];
  ///
  /// eventius.addListener((payload) {
  ///   log('event fired with payload: $payload');
  /// });
  ///
  /// eventius.fire('hert');
  /// ```
  FutureOr<void> fire(
    P payload, {
    bool useHistory = true,
    Duration? delay,
  }) async {
    if (delay != null) await Future.delayed(delay);

    _payloadsQueue.add(payload);

    if (historyLimit >= 0 && useHistory) _history.add(payload);

    /// If [historyLimit] is set to > 0 and the length of the list passed the
    /// given limit, then it is necessary to remove last added item from the
    /// list.
    if (historyLimit > 0 && _history.length > historyLimit) {
      _history.removeAt(0);
    }

    _loop();
  }

  /// Executes the event loop to process event payloads and listeners.
  ///
  /// During execution, the method iterates through the payloads queue invoking
  /// the associated once listeners for each payload.
  ///
  /// After processing the once listeners, the method invokes the regular
  /// listeners for the payload.
  void _loop() {
    if (_isBusy) return;
    _isBusy = true;

    while (_payloadsQueue.isNotEmpty) {
      final currentPayload = _payloadsQueue.removeAt(0);

      for (final onceListener in _onceListeners) {
        onceListener(currentPayload);
        _listenerToRemove.add(onceListener);
      }

      for (final listener in _listenerToRemove) {
        removeListener(listener, removeOnce: true);
      }

      for (final listener in _listeners) {
        listener(currentPayload);
      }
    }

    /// Resets state and marks event loop as not busy.
    _isBusy = false;
  }

  /// Adds a listener that will be invoked only once.
  ///
  /// Adds a [listener] function to the list of listeners that will be invoked
  /// only once for the next event.
  ///
  /// After invocation, the listener will automatically be removed from the list
  /// of listeners.
  ///
  /// ### Example:
  /// ```dart
  /// final eventius = Eventius<String>();
  ///
  /// void listener(String? payload) {
  ///   log('listener invoked with payload: $payload');
  /// }
  ///
  /// /// Add a once listener
  /// eventius.once(listener);
  ///
  /// eventius.fire('hert');
  ///
  /// /// The once listener will be invoked and automatically removed
  /// ```
  ListenerKiller once(EventiusListener<P> listener) {
    _onceListeners.add(listener);
    _listeners.add(listener);

    return () => removeListener(listener);
  }

  /// Adds a listener to the event manager.
  ///
  /// This method adds a [listener] function to the list of listeners associated
  /// with the event manager.
  ///
  /// Use [useHistory] parameter to control whether historical event payloads
  /// will be passed to the listener when it is added.
  ///
  /// Returns a [ListenerKiller] function that can be used to remove the added
  /// listener from the list of listeners.
  ///
  /// ### Example:
  /// ```dart
  /// final eventius = Eventius<String>();
  ///
  /// void listener(String? payload) {
  ///   log('listener invoked with payload: $payload');
  /// }
  ///
  /// /// Add a listener that responds to historical events as well
  /// eventius.addListener(listener);
  ///
  /// eventius.fire('hert');
  /// ```
  ///
  /// Note: The added listener can be removed manually using returned
  /// [ListenerKiller] function.
  ListenerKiller addListener(
    EventiusListener<P> listener, {
    bool useHistory = false,
  }) {
    _listeners.add(listener);

    if (historyLimit >= 0 && useHistory) {
      for (final payload in _history) {
        listener(payload);
      }
    }

    return () => removeListener(listener);
  }

  /// Adds filtered listener to the loop.
  ///
  /// The work principle is same as `addListener`.
  ///
  /// Provides an option to filter event payloads using a [filter] function. The
  /// [filter] parameter is a callback that determines whether the listener
  /// should be invoked for a particular event payload.
  ///
  /// Returns a [ListenerKiller] function that can be used to remove the added
  /// listener from the list of listeners.
  ///
  /// ### Example:
  /// ```dart
  /// final eventius = Eventius<int>();
  ///
  /// bool isEven(int number) => number % 2 == 0;
  ///
  /// void listener(int? payload) {
  ///   log('even number event: $payload');
  /// }
  ///
  /// eventius.addFilteredListener(listener, filter: isEven);
  ///
  /// /// Fire events and invoke the filtered listener for event numbers
  /// eventius.fire(1);
  /// eventius.fire(2); /// Invokes the listener
  /// ```
  ///
  /// Note: If you want to remove the added filtered listener manually, you can
  /// use the returned [ListenerKiller] function.
  ListenerKiller addFilteredListener(
    EventiusListener<P> listener, {
    required FilteredListener<P> filter,
    bool useHistory = false,
  }) =>
      addListener(
        (payload) {
          if (filter(payload)) listener(payload);
        },
        useHistory: useHistory,
      );

  /// Link the event manager to another event manager using a payload converter.
  ///
  /// Establishes a link between the current event manager and another
  /// [eventius] instance using a [converter] function.
  ///
  /// Use the [useHistory] parameter to control whether historical event
  /// payloads from the current event manager will be passed to the linked event
  /// manager.
  ///
  /// Optionally, [delay] can be introduced before forwarding the event to the
  /// linked event manager using the [delay] parameter.
  ///
  /// ### Example:
  /// ```dart
  /// final eventius = Eventius<int>();
  /// final eventius2 = Eventius<String>();
  ///
  /// String convertIntToString(int payload) => payload.toString();
  ///
  /// eventius.linkTo(eventius2, convertIntToString);
  ///
  /// eventius.fire(42);
  ///
  /// /// The linked eventius object will receive a converted event
  /// ```
  ///
  /// Note: If you want to remove the added filtered listener manually, you can
  /// use the returned [ListenerKiller] function.
  ListenerKiller linkTo<R>(
    Eventius<R> eventius,
    PayloadConverter<P, R> converter, {
    bool useHistory = true,
    Duration? delay,
  }) =>
      addListener(
        (payload) => eventius.fire(
          converter(payload),
          useHistory: useHistory,
          delay: delay,
        ),
      );

  /// Listens to events from another event manager and forwards them to this
  /// manager.
  ///
  /// Establishes a listening connection between the current event manager and
  /// another [eventius] instance.
  ///
  /// Use the [useHistory] parameter to control whether historical event
  /// payloads from the current event manager will be passed to the linked event
  /// manager.
  ///
  /// Optionally, [delay] can be introduced before forwarding the event to the
  /// linked event manager using the [delay] parameter.
  ///
  /// Returns a [ListenerKiller] function that can be used to stop listening to
  /// events from the source event manager and halt forwarding.
  ///
  /// ### Example:
  /// ```dart
  /// final eventius = Eventius<int>();
  /// final eventius2 = Eventius<int>();
  ///
  /// /// Listen to events from the source event manager and forward them to the target
  /// eventius2.listenTo(eventius2);
  ///
  /// eventius.fire(42);
  ///
  /// /// The target event manager will receive the forwarded event
  /// ```
  ///
  /// [ListenerKiller] can be used to stop listening to events and halt
  /// forwarding manually.
  ListenerKiller listenTo(
    Eventius<P> eventius, {
    bool useHistory = true,
    Duration? delay,
  }) =>
      eventius.addListener(
        (payload) => fire(
          payload,
          useHistory: useHistory,
          delay: delay,
        ),
      );

  /// Removes a listener from the event manager.
  ///
  /// [listener] represents the listener function to be removed.
  ///
  /// Optionally, [removeOnce] parameter can specified for indicating whether to
  /// remove the listener from the list of once listeners. Defaults to `false`.
  void removeListener(EventiusListener<P> listener, {bool removeOnce = false}) {
    _listeners.remove(listener);

    if (removeOnce) {
      _onceListeners.remove(listener);
    }
  }

  /// Clears listeners based on an optional filter or clear all listeners.
  ///
  /// The [filter] parameter is a callback function that takes an
  /// [EventiusListener] and returns a `bool` value.
  ///
  /// ### Example:
  /// ```dart
  /// final eventius = Eventius<String>();
  ///
  /// eventius.addListener((payload) {});
  ///
  /// /// Clear all listeners
  /// eventius.clear();
  /// ```
  void clear([bool Function(EventiusListener<P>)? filter]) =>
      filter == null ? _listeners.clear() : _listeners.removeWhere(filter);

  /// Clears the historical event payloads.
  ///
  /// Removes all historical event payloads that have been recorded by the event
  /// manager.
  void clearHistory() => _history.clear();
}
