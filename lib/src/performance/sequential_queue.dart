import 'dart:async' as async;

/// Processes a [Stream]'s events one at a time, in order.
///
/// [Stream.listen] does not wait for an asynchronous callback to complete
/// before delivering the next event, so async pre-send work can interleave and
/// let a later stanza overtake an earlier one. This chains every event onto the
/// previous event's future, which keeps processing strictly FIFO while leaving
/// the underlying subscription cancellable — unlike an `await for` loop, which
/// can only be stopped by closing the stream.
class SequentialQueue<T> {
  /// Subscribes to [stream] and runs [process] for each event in turn.
  ///
  /// Errors thrown by [process], and errors emitted by [stream] itself, are
  /// reported to [onError] and do not stop processing. When [onError] is
  /// omitted they are forwarded to the current [async.Zone].
  SequentialQueue({
    required async.Stream<T> stream,
    required Future<void> Function(T event) process,
    void Function(Object error, StackTrace stackTrace)? onError,
  })  : _process = process,
        _onError = onError {
    _subscription = stream.listen(
      _enqueue,
      onError: _reportError,
      cancelOnError: false,
    );
  }

  final Future<void> Function(T event) _process;

  final void Function(Object error, StackTrace stackTrace)? _onError;

  late final async.StreamSubscription<T> _subscription;

  /// Tail of the processing chain. Every delivered event is appended to it.
  async.Future<void> _tail = async.Future<void>.value();

  bool _cancelled = false;

  /// Completes once every event delivered so far has been processed.
  ///
  /// Events delivered after this getter is read are not covered by the
  /// returned future.
  async.Future<void> get drained => _tail;

  void _enqueue(T event) {
    /// Assigned synchronously so a later event cannot claim the chain ahead of
    /// this one. The cancellation check runs when the event's turn comes up,
    /// not when it is delivered — a listener callback returns immediately here,
    /// so a stream's whole buffer can be delivered long before it is processed.
    _tail = _tail.then((_) {
      if (_cancelled) return null;
      return _process(event);
    }).catchError(_reportError);
  }

  void _reportError(Object error, StackTrace stackTrace) {
    final onError = _onError;
    if (onError == null) {
      async.Zone.current.handleUncaughtError(error, stackTrace);
    } else {
      onError(error, stackTrace);
    }
  }

  /// Stops processing.
  ///
  /// Events already delivered but not yet processed are dropped; an event
  /// currently being processed still runs to completion, so await [drained] to
  /// wait for it.
  Future<void> cancel() {
    _cancelled = true;
    return _subscription.cancel();
  }
}
