import 'dart:async';

import 'package:synchronized/extension.dart';

/// A typedef for a function that removes a listener.
///
/// The [_RemoveListener] function is returned when registering a listener,
/// and it can be used to remove the listener at a later point.
typedef _RemoveListener = void Function();

/// A typedef for a function that handles an event with optional data.
///
/// The [_Handler] function is used as type for event handlers, and it can
/// process event data or perform other tasks.
typedef _Handler<B> = FutureOr<void> Function(B? data);

/// [_Eventius] class is an abstract class that defines the core functionality
/// for event handling. It includes methods for registering and removing
/// listeners, emitting events, and clearing the event registry.
///
/// Users typically interact with the concrete implementation class [Eventius],
/// which extends this class.
abstract class _Eventius {
  /// A [Map] to store registered events and their corresponding handlers.
  late final _events = <String, List<dynamic>>{};

  /// Registers a listener for the sprecified [event] with the given [handler].
  _RemoveListener on<B>(String event, _Handler<B> handler);

  /// Register a one-time listener for the specified [event] with the given
  /// [handler].
  void once<A>(String event, _Handler<A> handler);

  /// Emits an event with optional data to all registered listeners for that
  /// event.
  Future<void> emit<B>(String event, [B? data]);

  ///Removes all listeners for the specified event.
  void off(String event);

  /// Removes all listeners for all events, effectively clearing the event
  /// registry.
  void clear();
}

/// An event-driven library for this package providing a simple and flexible
/// event management system.
///
/// Extends [_Eventius], which is an abstract class defining the core
/// functionality for event handling. [Eventius] allows registration of
/// listeners, emission of events, and removal of listeners, Listeners can be
/// added for specific events and can be removed individually or all at once.
class Eventius extends _Eventius {
  /// Registers a listener for the specified [event] with he given [handler].
  ///
  /// The [event] parameter is the name of the event to listen for, and the
  /// [handler] parameter is the function to b called when the event occurs.
  ///
  /// The returned function can be used to remove the registered listener.
  ///
  /// ### Example:
  /// ```dart
  /// final eventius = Eventius();
  /// final removeListener = eventius.on<String>('exampleEvent', (data) {
  ///   log('Something happened and here is data: $data');
  /// });
  ///
  /// /// ...you can remove the listener after by calling the assigned value.
  ///
  /// removeListener.call();
  /// ```
  @override
  _RemoveListener on<B>(String event, _Handler<B> handler) {
    final List<_Handler<B>> handlerContainer = _events.putIfAbsent(
      event,
      () => <_Handler<B>>[],
    ) as List<_Handler<B>>;

    void offThislistener() => handlerContainer.remove(handler);

    handlerContainer.add(handler);

    return () => offThislistener();
  }

  /// Registers a one-time listener for the specified [event] with the given
  /// [handler].
  ///
  /// The [event] parameter is the name of the event to listen for, and the
  /// [handler] parameter is the function to be called when the event occurs.
  /// After the first occurance of the event, the listener is automatically
  /// removed.
  ///
  /// ### Example:
  /// ```dart
  /// eventius.once<String>('onceEvent', (data) {
  ///   log('do something with the one-time handler data: $data');
  /// });
  /// ```
  @override
  void once<A>(String event, _Handler<A> handler) {
    final List<_Handler<A>> handlerContainer =
        _events.putIfAbsent(event, () => <_Handler<A>>[]) as List<_Handler<A>>;
    handlerContainer.add(
      (A? data) async {
        if (handler is Future) {
          await synchronized(() => handler.call(data));
        } else {
          handler.call(data);
        }
        off(event);
      },
    );
  }

  /// Emits an event with optional [data] to all registered listeners for that
  /// [event].
  ///
  /// The [event] parameter is the name of the event to emit, and the
  /// optional [data] parameter can carry additional information to be passed to
  /// the event handlers.
  ///
  /// ### Example:
  /// ```dart
  /// eventius.emit<String>('event', 'salam!');
  /// ```
  @override
  Future<void> emit<B>(String event, [B? data]) async {
    final List<_Handler<B>> handlerContainer =
        _events.putIfAbsent(event, () => <_Handler<B>>[]) as List<_Handler<B>>;
    for (final handler in handlerContainer) {
      if (handler is Future) {
        await synchronized(() => handler.call(data));
      } else {
        handler.call(data);
      }
    }
  }

  /// Removes all listeners for the specified [event].
  ///
  /// The [event] parameter is the name of the event for which all listeners
  /// should be removed.
  ///
  /// ### Example:
  /// ```dart
  /// eventius.off('event');
  /// ```
  @override
  void off(String event) => _events.remove(event);

  /// Removes all listeners for all events, clearing the event registry.
  ///
  /// ### Example:
  /// ```dart
  /// eventius.clear();
  /// ```
  @override
  void clear() => _events.clear();

  /// Gets a [Map] representing the current state of registered events and
  /// their handlers.
  ///
  /// The returned [Map] contains event names as keys and lists of handlers as
  /// values.
  ///
  /// ### Example:
  /// ```dart
  /// log(eventius.events); /// this will output currently active event handlers
  /// ```
  Map<String, List<FutureOr>> get events => _events;
}
