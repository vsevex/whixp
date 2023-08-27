import 'dart:async';

import 'package:event/src/eventius.dart';

/// Abstract base class for creating event objects with associated event
/// manager.
///
/// Serves as an abstract base class for creating event objects that are
/// associated with an [Eventius] instance.
///
/// ### Example:
/// ```dart
/// class EventClass extends EventObject<String> {
///   EventClass() : super(name: 'event', historyLimit: 10);
///
///   void fireEvent(String payload) {
///     eventius.fire(payload);
///   }
/// }
///
/// final event = EventClass();
///
/// /// Add a listener to the event object
/// event.on((payload) {
///   log('listener invoked with payload: $payload');
/// });
///
/// /// Fire an event using the custom method
/// event.fireEvent('hert');
/// ```
abstract class EventObject<P> {
  /// Creates a new [EventObject] object whose default [name] is `eventius` and
  /// [historyLimit] is `-1`.
  EventObject({String name = 'eventius', int historyLimit = -1})
      : eventius = Eventius<P>(name: name, historyLimit: historyLimit);

  /// The associated [Eventius] instance for managing events.
  late final Eventius<P> eventius;

  /// Returns the last event payload that was fired.
  ///
  /// This property is used to retrieve the last event payload that was fired
  /// using the associated [eventius] instance.
  P? get lastPayload => eventius.lastPayload;

  /// Fires an event with the given payload.
  ///
  /// Forwards the provided [payload] to the associated [eventius] instance for
  /// processing. The event [payload] can be controlled whether to be added to
  /// the historical record or not by the parameter of [useHistory].
  ///
  /// Optionally, [delay] can be introduced before firing the event. This can be
  /// useful to simulate asynchronous event propagation.
  ///
  /// ### Example:
  /// ```dart
  /// class EventClass extends EventObject<String> {
  ///   EventClass() : super(name: 'event', historyLimit: 10);
  /// }
  ///
  /// final event = EventClass();
  ///
  /// event.fire('blya', useHistory: false);
  /// ```
  FutureOr<void> fire(P payload, {bool useHistory = true, Duration? delay}) =>
      eventius.fire(payload, useHistory: useHistory, delay: delay);

  /// Adds a listener to the associated event manager.
  ///
  /// This method adds a listener function to the list of listeners associated
  /// with the associated [eventius] instance.
  ///
  /// Use [useHistory] parameter to control whether historical event payloads
  /// will be passed to the listener when it is added. Additionally, you can
  /// provide a [filter] callback to selectively invoke the listener based on
  /// event payload criteria.
  ///
  /// Returns a [ListenerKiller] function that can be used to remove the added
  /// listener.
  ///
  /// ### Example:
  /// ```dart
  /// class EventClass extends EventObject<int> {
  ///   EventClass() : super(name: 'event', historyLimit: 10);
  /// }
  ///
  /// void listener(int payload) {
  ///   log('listener invoked with payload: $payload');
  /// }
  ///
  /// final event = EventClass();
  ///
  /// event.on(listener);
  ///
  /// event.fire(42);
  /// ```
  ListenerKiller on(
    EventiusListener<P> listener, {
    bool useHistory = true,
    FilteredListener<P>? filter,
  }) {
    /// If there is no filter provided add regular listener.
    if (filter == null) {
      return eventius.addListener(listener, useHistory: useHistory);
    } else {
      return eventius.addFilteredListener(
        listener,
        filter: filter,
        useHistory: useHistory,
      );
    }
  }

  /// Adds a listener that will be invoked only once to the [eventius] instance.
  ///
  /// Adds a [listener] function to the list of listeners that will be invoked
  /// only once for the next event.
  ///
  /// ### Example:
  /// ```dart
  /// class EventClass extends EventObject<String> {
  ///   EventClass() : super(name: 'event', historyLimit: 10);
  /// }
  ///
  /// void listener(String payload) {
  ///   log('do something with the passed payload once');
  /// }
  ///
  /// final event = EventClass();
  ///
  /// event.once(listener);
  ///
  /// event.fire('hert');
  /// ```
  ListenerKiller once(EventiusListener<P> listener) => eventius.once(listener);

  /// Establishes a link between the associated event manager and another
  /// [eventius] event manager using [converter] function.
  ///
  /// Use the [useHistory] parameter to control whether historical event
  /// payloads from the current event manager will be passed to the linked event
  /// manager.
  ///
  /// Optionally, [delay] can be introduced before forwarding the event to the
  /// linked event manager using the [delay] parameter.
  ///
  /// Returns a [ListenerKiller] function that can be used to remove the added
  /// link.
  ///
  /// ### Example:
  /// ```dart
  /// class EventClass extends EventObject<int> {
  ///   EventClass() : super(name: 'event', historyLimit: 10);
  /// }
  ///
  /// class AnotherEventClass extends EventObject<String> {
  ///   AnotherEventClass() : super(name: 'anotherEvent', historyLimit: 0);
  /// }
  ///
  /// final event = EventClass();
  /// final anotherEvent = AnotherEventClass();
  ///
  /// String convertIntToString(int payload) => payload.toString();
  ///
  /// event.linkTo(anotherEvent, convertIntToString);
  ///
  /// event.fire(42);
  /// ```
  ListenerKiller linkTo<R>(
    Eventius<R> eventius,
    PayloadConverter<P, R> converter, {
    bool useHistory = true,
    Duration? delay,
  }) =>
      this
          .eventius
          .linkTo(eventius, converter, delay: delay, useHistory: useHistory);

  /// Listens to events from another event manager and forwards them to the
  /// associated manager.
  ///
  /// Establishes a listening connection between the associated [eventius]
  /// instance and another [eventius] instance. This captures events fired in
  /// the source event manager and forwards them to the associated manager for
  /// processing.
  ///
  /// ### Example:
  /// ```dart
  /// class EventClass extends EventObject<int> {
  ///   EventClass() : super(name: 'event', historyLimit: 10);
  /// }
  ///
  /// class AnotherEventClass extends EventObject<String> {
  ///   AnotherEventClass() : super(name: 'anotherEvent', historyLimit: 0);
  /// }
  ///
  /// final event = EventClass();
  /// final anotherEvent = AnotherEventClass();
  ///
  /// event.listenTo(anotherEvent);
  ///
  /// event.fire(41);
  /// ```
  ListenerKiller listenTo(
    Eventius<P> eventius, {
    bool useHistory = true,
    Duration? delay,
  }) =>
      this.eventius.listenTo(eventius, useHistory: useHistory, delay: delay);
}
