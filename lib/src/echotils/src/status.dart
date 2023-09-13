/// All possible statuses enumerated, for further information please refer to
/// `status` constant.
enum EchoStatus {
  authenticating,
  authenticated,
  authenticationFailed,
  bindingRequired,
  connecting,
  connected,
  connectionFailed,
  connectionTimeout,
  disconnecting,
  disconnected,
  error,
  reconnecting,
  reconnected,
  redirect,
  offline,
}
