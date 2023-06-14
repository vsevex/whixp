import 'dart:async';

part 'eventius.dart';

/// Abstract class representing an event.
///
/// An event is a specific occurrence that can be observed or triggered in a
/// program.
///
/// This class is designed to be extended by concrete event classes.
/// It provides a basic structure and functionality for events.
///
/// Type parameter:
/// - P: The type of callback associated with the event.
///
/// Example usage:
/// ```dart
/// class MyEvent extends Event<int> {
///   MyEvent() : super(name: 'someEvent');
/// }
/// ```
abstract class Event<P> {
  /// Creates a new instacne of the [Event] class.
  ///
  /// * @param name The name of the event. Default to `event`.
  Event({String name = 'event'}) : event = Eventius<P>(name: name);

  /// The underlaying event object.
  late final Eventius<P> event;

  /// Fires a null callback.
  ///
  /// Fore more information take a look at [Eventius.notify].
  void notify([Duration? delay]) => event.notify(delay);

  /// Fire the [callback] to all listeners.
  ///
  /// Fore more information take a look at [Eventius.fire].
  void fire(P callback, {Duration? delay}) =>
      event.fire(callback, delay: delay);

  /// Add [listener] to the current [event].
  ListenerKiller on(EventiusListener<P> listener, {ListenerFilter<P>? filter}) {
    if (filter == null) {
      return event.addListener(listener);
    } else {
      return event.addFilteredListener(listener, filter);
    }
  }

  /// Remove [listener] from the current [event].
  ///
  /// For more information please take a look at [Eventius.removeListener].
  void off(EventiusListener<P> listener) => event.removeListener(listener);

  /// Listens to another [Eventius] of the same type.
  ///
  /// For more information please take a look at [Eventius.listenTo].
  ListenerKiller listenTo(Eventius<P> event, {Duration? delay}) =>
      event.listenTo(event, delay: delay);
}
