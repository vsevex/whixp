/// Interface for handling socket events, replacing ConnectaListener.
///
/// This interface provides callbacks for socket data, errors, completion,
/// and data combination logic.
abstract class SocketListener {
  /// Called when data is received from the socket.
  void onData(List<int> bytes);

  /// Called when the socket connection is closed.
  void onDone();

  /// Called when an error occurs on the socket.
  void onError(Object exception, StackTrace trace);

  /// Determines whether to continue combining incoming data.
  ///
  /// Returns `true` if data should continue to be combined, `false` otherwise.
  /// This is useful for protocols where messages may arrive in chunks.
  bool combineWhile(List<int> bytes);
}
