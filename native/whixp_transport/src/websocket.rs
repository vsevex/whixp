//! WebSocket transport for XMPP (RFC 7395 style: one stanza per frame or concatenated).
//! Uses tungstenite over TCP or existing TLS stream; exposes Read/Write for the stanza loop.

use std::io::{Read, Write};

use tungstenite::client::client;
use tungstenite::Message;
use tungstenite::WebSocket;

use crate::handshake::HandshakeError;
use crate::tls;

/// Build WebSocket request URL from host, port, path, and TLS flag.
fn ws_url(host: &str, port: u16, path: &str, use_tls: bool) -> String {
    let scheme = if use_tls { "wss" } else { "ws" };
    let path = path.trim_start_matches('/');
    if path.is_empty() {
        format!("{}://{}:{}", scheme, host, port)
    } else {
        format!("{}://{}:{}/{}", scheme, host, port, path)
    }
}

/// Wraps tungstenite::WebSocket so we can use it as std::io::Read + Write (one message = one chunk).
pub struct WsStream<S> {
    ws: WebSocket<S>,
    read_buf: Vec<u8>,
    read_pos: usize,
}

impl<S> WsStream<S>
where
    S: Read + Write,
{
    fn new(ws: WebSocket<S>) -> Self {
        Self {
            ws,
            read_buf: Vec::new(),
            read_pos: 0,
        }
    }
}

/// Set underlying TCP stream to non-blocking after handshake so the read/write threads
/// don't deadlock (read would otherwise hold the lock until server sends).
impl WsStream<std::net::TcpStream> {
    pub fn set_tcp_nonblocking(&mut self, nonblocking: bool) -> std::io::Result<()> {
        self.ws.get_mut().set_nonblocking(nonblocking)
    }
}

impl<S> Read for WsStream<S>
where
    S: Read + Write,
{
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        if self.read_pos >= self.read_buf.len() {
            let msg = self.ws.read().map_err(|e| {
                if let tungstenite::Error::Io(ioe) = e {
                    ioe
                } else {
                    std::io::Error::new(std::io::ErrorKind::Other, e.to_string())
                }
            })?;
            match msg {
                Message::Text(_) | Message::Binary(_) => {
                    self.read_buf = msg.into_data().to_vec();
                    self.read_pos = 0;
                }
                Message::Close(_) | Message::Frame(_) => return Ok(0),
                Message::Ping(_) | Message::Pong(_) => return self.read(buf),
            }
        }
        let from = &self.read_buf[self.read_pos..];
        let n = from.len().min(buf.len());
        buf[..n].copy_from_slice(&from[..n]);
        self.read_pos += n;
        Ok(n)
    }
}

impl<S> Write for WsStream<S>
where
    S: Read + Write,
{
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        let s = String::from_utf8_lossy(buf).into_owned();
        self.ws
            .send(Message::text(s))
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e.to_string()))?;
        Ok(buf.len())
    }

    fn flush(&mut self) -> std::io::Result<()> {
        self.ws
            .flush()
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::Other, e.to_string()))
    }
}

/// Connect WebSocket (no TLS) over existing TCP stream. Caller must have already connected
/// the stream to host:port. Returns a stream that implements Read + Write (XMPP stanzas as text frames).
pub fn connect_websocket(
    host: &str,
    port: u16,
    path: &str,
    stream: std::net::TcpStream,
) -> Result<WsStream<std::net::TcpStream>, HandshakeError> {
    let url = ws_url(host, port, path, false);
    let (ws, _) = client(url, stream).map_err(|e| HandshakeError::Connection(e.to_string()))?;
    Ok(WsStream::new(ws))
}

/// Connect WebSocket over TLS (wss). Uses existing TLS stream from tls::connect_direct.
pub fn connect_websocket_tls(
    host: &str,
    port: u16,
    path: &str,
    tls_stream: tls::TlsStreamWrapper,
) -> Result<WsStream<tls::TlsStreamWrapper>, HandshakeError> {
    let url = ws_url(host, port, path, true);
    let (ws, _) = client(url, tls_stream).map_err(|e| HandshakeError::Connection(e.to_string()))?;
    Ok(WsStream::new(ws))
}
