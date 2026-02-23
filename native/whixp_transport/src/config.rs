//! Connection configuration: host, port, TLS, WebSocket, timeouts.
//! Passed from Dart after DNS resolution (DNS stays on Dart side).

use std::time::Duration;

/// Transport type: TCP (with optional StartTLS), Direct TLS, or WebSocket.
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TransportKind {
    Tcp = 0,
    TcpStartTls = 1,
    DirectTls = 2,
    WebSocket = 3,
    WebSocketTls = 4,
}

/// Configuration for the Rust transport layer.
/// host = domain to resolve (SRV + A/AAAA in Rust); service = e.g. "xmpp-client".
#[derive(Clone, Debug)]
pub struct TransportConfig {
    /// Domain to resolve (and use for SRV _service._tcp.domain if service is set).
    pub host: String,
    pub port: u16,
    pub kind: TransportKind,
    pub connect_timeout_ms: u32,
    pub tls_server_name: Option<String>,
    /// SRV service name (e.g. "xmpp-client") or None to skip SRV.
    pub service: Option<String>,
    pub use_ipv6: bool,
    /// WebSocket path (e.g. "/ws" or "/xmpp-websocket")
    pub ws_path: Option<String>,
}

impl Default for TransportConfig {
    fn default() -> Self {
        Self {
            host: String::new(),
            port: 5222,
            kind: TransportKind::TcpStartTls,
            connect_timeout_ms: 2000,
            tls_server_name: None,
            service: None,
            use_ipv6: false,
            ws_path: Some("/ws".to_string()),
        }
    }
}

impl TransportConfig {
    pub fn connect_timeout(&self) -> Duration {
        Duration::from_millis(self.connect_timeout_ms as u64)
    }
}
