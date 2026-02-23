//! Connection lifecycle: connect, send, receive loop, disconnect.
//! Spawns a thread that does read loop (stanza framing) and send channel.

use std::cell::RefCell;
use std::io::{Read, Write};
use std::net::{TcpStream, ToSocketAddrs};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc;
use std::sync::Arc;
use std::thread;
use std::time::Duration;

use crate::config::{TransportConfig, TransportKind};
use crate::dns;
use crate::handshake::HandshakeError;
use crate::retry::RetryPolicy;
use crate::stanza::StreamFramer;
use crate::tls;
use crate::websocket;

type Result<T> = std::result::Result<T, HandshakeError>;

/// Connection state for callbacks to Dart. Must match Dart TransportState order where used.
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum TransportState {
    Disconnected = 0,
    Connecting = 1,
    Connected = 2,
    TlsSuccess = 3,
    Disconnecting = 4,
    ConnectionFailure = 5,
    Reconnecting = 6,
}

/// Either TCP, TLS, or WebSocket stream so we can have one read/write loop.
enum StreamKind {
    Tcp(TcpStream),
    Tls(tls::TlsStreamWrapper),
    Ws(websocket::WsStream<TcpStream>),
    WsTls(websocket::WsStream<tls::TlsStreamWrapper>),
}

impl Read for StreamKind {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        match self {
            StreamKind::Tcp(s) => s.read(buf),
            StreamKind::Tls(s) => s.read(buf),
            StreamKind::Ws(s) => s.read(buf),
            StreamKind::WsTls(s) => s.read(buf),
        }
    }
}

impl Write for StreamKind {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        match self {
            StreamKind::Tcp(s) => s.write(buf),
            StreamKind::Tls(s) => s.write(buf),
            StreamKind::Ws(s) => s.write(buf),
            StreamKind::WsTls(s) => s.write(buf),
        }
    }
    fn flush(&mut self) -> std::io::Result<()> {
        match self {
            StreamKind::Tcp(s) => s.flush(),
            StreamKind::Tls(s) => s.flush(),
            StreamKind::Ws(s) => s.flush(),
            StreamKind::WsTls(s) => s.flush(),
        }
    }
}

/// Events sent to Dart via channel (no callbacks from threads).
pub enum TransportEvent {
    State(i32),
    Stanza(String),
    Error(i32, String),
}

/// Sender for events; connection threads use this instead of callbacks.
pub type EventSender = mpsc::Sender<TransportEvent>;

/// Internal connection context.
pub struct Connection {
    config: TransportConfig,
    #[allow(dead_code)]
    retry: RetryPolicy,
    shutdown: Arc<AtomicBool>,
    tx: RefCell<Option<mpsc::Sender<Vec<u8>>>>,
}

impl Connection {
    pub fn new(config: TransportConfig, retry: RetryPolicy) -> Self {
        Self {
            config,
            retry,
            shutdown: Arc::new(AtomicBool::new(false)),
            tx: RefCell::new(None),
        }
    }

    /// Resolve (SRV + A/AAAA) then connect. Returns resolved host on success for TLS SNI / SASL.
    pub fn connect_sync(&mut self, event_tx: EventSender) -> Result<String> {
        let (host, port) = dns::resolve_xmpp(
            &self.config.host,
            self.config.port,
            self.config.service.as_deref(),
            self.config.use_ipv6,
        )?;
        let timeout = self.config.connect_timeout();
        let kind = self.config.kind;

        let stream: StreamKind = match kind {
            TransportKind::DirectTls => {
                let s = tls::connect_direct(&host, port, false)?;
                StreamKind::Tls(s)
            }
            TransportKind::Tcp | TransportKind::TcpStartTls => {
                let addr = format!("{}:{}", host, port);
                let mut addrs = addr
                    .to_socket_addrs()
                    .map_err(|e: std::io::Error| HandshakeError::Connection(e.to_string()))?;
                let first = addrs
                    .next()
                    .ok_or_else(|| HandshakeError::Connection("no address".into()))?;
                let tcp = TcpStream::connect_timeout(&first, timeout)
                    .map_err(|e| HandshakeError::Connection(e.to_string()))?;
                // Non-blocking read: we only hold the lock for one quick read() syscall, so the write
                // thread can send (e.g. bind IQ) immediately instead of waiting for read timeout.
                let _ = tcp.set_nonblocking(true);
                let _ = tcp.set_write_timeout(Some(Duration::from_secs(10)));
                StreamKind::Tcp(tcp)
            }
            TransportKind::WebSocket => {
                let addr = format!("{}:{}", host, port);
                let mut addrs = addr
                    .to_socket_addrs()
                    .map_err(|e: std::io::Error| HandshakeError::Connection(e.to_string()))?;
                let first = addrs
                    .next()
                    .ok_or_else(|| HandshakeError::Connection("no address".into()))?;
                let tcp = TcpStream::connect_timeout(&first, timeout)
                    .map_err(|e| HandshakeError::Connection(e.to_string()))?;
                // Keep stream blocking for WebSocket handshake (tungstenite does blocking read of 101 response).
                let _ = tcp.set_write_timeout(Some(Duration::from_secs(10)));
                let path = self.config.ws_path.as_deref().unwrap_or("/ws");
                let mut ws = websocket::connect_websocket(&host, port, path, tcp)?;
                // Non-blocking so read thread releases lock when no data; write thread can send stream header.
                let _ = ws.set_tcp_nonblocking(true);
                StreamKind::Ws(ws)
            }
            TransportKind::WebSocketTls => {
                let tls_stream = tls::connect_direct(&host, port, false)?;
                let path = self.config.ws_path.as_deref().unwrap_or("/ws");
                let ws = websocket::connect_websocket_tls(&host, port, path, tls_stream)?;
                StreamKind::WsTls(ws)
            }
        };

        let _ = event_tx.send(TransportEvent::State(TransportState::Connected as i32));

        let (send_tx, send_rx) = mpsc::channel::<Vec<u8>>();
        let shutdown = Arc::clone(&self.shutdown);
        let stream = Arc::new(std::sync::Mutex::new(stream));

        let stream_read = Arc::clone(&stream);
        let shutdown_read = Arc::clone(&shutdown);
        let event_tx_read = event_tx.clone();
        thread::spawn(move || {
            let mut framer = StreamFramer::new();
            let mut buf = [0u8; 8192];
            loop {
                if shutdown_read.load(Ordering::SeqCst) {
                    break;
                }
                let n = match stream_read.lock().unwrap().read(&mut buf) {
                    Ok(0) => {
                        eprintln!("[Whixp] read loop exit: EOF");
                        break;
                    }
                    Ok(n) => n,
                    Err(e) => {
                        let kind = e.kind();
                        if kind == std::io::ErrorKind::TimedOut
                            || kind == std::io::ErrorKind::WouldBlock
                            || kind == std::io::ErrorKind::Interrupted
                        {
                            std::thread::yield_now();
                            continue;
                        }
                        eprintln!("[Whixp] read loop exit: error {:?}", kind);
                        break;
                    }
                };
                if let Ok(stanzas) = framer.push(&buf[..n]) {
                    for s in stanzas {
                        let _ = event_tx_read.send(TransportEvent::Stanza(s));
                    }
                }
            }
            let _ = event_tx_read.send(TransportEvent::State(TransportState::Disconnected as i32));
        });

        let stream_write = Arc::clone(&stream);
        let shutdown_write = Arc::clone(&shutdown);
        let event_tx_write = event_tx.clone();
        thread::spawn(move || {
            while !shutdown_write.load(Ordering::SeqCst) {
                match send_rx.recv() {
                    Ok(data) => {
                        if let Err(e) = stream_write.lock().unwrap().write_all(&data) {
                            let _ = event_tx_write.send(TransportEvent::Error(1, e.to_string()));
                            break;
                        }
                        let _ = stream_write.lock().unwrap().flush();
                    }
                    Err(_) => break,
                }
            }
        });

        *self.tx.borrow_mut() = Some(send_tx);
        Ok(host)
    }

    pub fn send(&self, data: &[u8]) -> Result<()> {
        if let Some(ref tx) = *self.tx.borrow() {
            tx.send(data.to_vec())
                .map_err(|_| HandshakeError::Connection("send channel closed".into()))?;
            Ok(())
        } else {
            Err(HandshakeError::Connection("not connected".into()))
        }
    }

    pub fn shutdown(&self) {
        self.shutdown.store(true, Ordering::SeqCst);
        drop(self.tx.borrow_mut().take());
    }
}
