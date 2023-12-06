import 'dart:async';

class AsyncQueue<T> {
  final StreamController<T> _controller = StreamController<T>.broadcast();
  late StreamSubscription<T> _subscription;
  final List<T> _queue = [];

  void enqueue(T item) {
    _queue.add(item);
    _controller.add(item);
  }

  Future<T> dequeue() async {
    if (_queue.isNotEmpty) {
      return _queue.removeAt(0);
    } else {
      final completer = Completer<T>();
      _subscription = _controller.stream.listen((T item) {
        completer.complete(item);
      });
      return completer.future;
    }
  }

  void close() {
    _controller.close();
    _subscription.cancel();
  }
}
