/// Connection status constants for use by the connection handler callback.
///
/// * _[OPEN]_ - The client is logged in to the XMPP network and is able to
/// receive messages.
/// * _[CONNECTING]_ - The connection is currently being made.
/// * _[CONNECTED]_ - The connection has succeeded.
/// * _[AUTHENTICATED]_ - The client has been authenciated by the XMPP server.
/// * _[DISCONNECTED]_ - The connection has been terminated.
/// * _[ERROR]_ - An error has occurred.
/// * _[OFFLINE]_ - Connection terminated or the client has gone to offline
/// manually.
const status = <EchoStatus, int>{
  EchoStatus.open: 0,
  EchoStatus.connecting: 1,
  EchoStatus.connected: 2,
  EchoStatus.authenticated: 3,
  EchoStatus.disconnected: 4,
  EchoStatus.error: 5,
  EchoStatus.offline: 6,
};

/// All possible statuses enumerated, for further information please refer to
/// `status` constant.
enum EchoStatus {
  open,
  connecting,
  connected,
  authenticated,
  disconnected,
  error,
  offline,
}
