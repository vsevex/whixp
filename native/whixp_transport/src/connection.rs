//! Connection lifecycle: connect, send, receive loop, disconnect.
//! Spawns a thread that does read loop (stanza framing) and send channel.

use std::cell::RefCell;
use std::io::{Read, Write};
use std::net::{TcpStream, ToSocketAddrs};
use std::sync::mpsc;
use std::thread;
use std::thread::JoinHandle;
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

impl StreamKind {
    fn upgrade_tls(&mut self, domain: &str) -> Result<()> {
        let new = match self {
            StreamKind::Tcp(tcp) => {
                let tls = tls::upgrade_tcp(
                    std::mem::replace(tcp, unsafe {
                        std::mem::zeroed()
                    }),
                    domain,
                    false,
                )?;
                StreamKind::Tls(tls)
            }

            _ => {
                return Err(HandshakeError::Connection(
                    "cannot upgrade".into(),
                ));
            }
        };

        *self = new;
        Ok(())
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

pub enum TransportCommand {
    Send(Vec<u8>),

    Shutdown,
}

struct TransportWorker {
    host: String,
    stream: StreamKind,
    command_rx: mpsc::Receiver<TransportCommand>,
    event_tx: EventSender,
    framer: StreamFramer,
}

impl TransportWorker {
    fn is_starttls_proceed(stanza: &str) -> bool {
        stanza.contains("<proceed")
            && stanza.contains("xmpp-tls")
    }

    fn handle_starttls(&mut self) -> Result<()> {

        // 1. emit state change
        let _ = self.event_tx.send(
            TransportEvent::State(
                TransportState::TlsSuccess as i32
            )
        );

        // 2. upgrade stream IN PLACE
        let _ = self.stream.upgrade_tls(&self.host);

        // 3. IMPORTANT:
        // XMPP requires stream restart after TLS
        // but Rust should NOT send it automatically
        //
        // Dart will send:
        // <stream:stream> after receiving TlsSuccess

        Ok(())
    }

    fn run(mut self) {
        let mut buf = [0u8; 8192];

        loop {
            //
            // COMMAND PHASE
            //
            loop {
                match self.command_rx.try_recv() {
                    Ok(TransportCommand::Send(data)) => {
                        if let Err(e) = self.stream.write_all(&data) {
                            let _ = self.event_tx.send(
                                TransportEvent::Error(1, e.to_string())
                            );

                            let _ = self.event_tx.send(
                                TransportEvent::State(
                                    TransportState::Disconnected as i32
                                )
                            );

                            return;
                        }

                        let _ = self.stream.flush();
                    }

                    Ok(TransportCommand::Shutdown) => {
                        let _ = self.event_tx.send(
                            TransportEvent::State(
                                TransportState::Disconnecting as i32
                            )
                        );

                        let _ = self.event_tx.send(
                            TransportEvent::State(
                                TransportState::Disconnected as i32
                            )
                        );

                        return;
                    }

                    Err(mpsc::TryRecvError::Empty) => {
                        break;
                    }

                    Err(mpsc::TryRecvError::Disconnected) => {
                        let _ = self.event_tx.send(
                            TransportEvent::State(
                                TransportState::Disconnected as i32
                            )
                        );

                        return;
                    }
                }
            }

            //
            // READ PHASE
            //
            match self.stream.read(&mut buf) {
                Ok(0) => {
                    let _ = self.event_tx.send(
                        TransportEvent::State(
                            TransportState::Disconnected as i32
                        )
                    );

                    return;
                }

                Ok(n) => {
                    match self.framer.push(&buf[..n]) {
                        Ok(stanzas) => {
                            for stanza in stanzas {
                                if Self::is_starttls_proceed(&stanza) {
                                    let _ = self.handle_starttls();
                                    continue;
                                }

                                let _ = self.event_tx.send(
                                    TransportEvent::Stanza(stanza)
                                );
                            }
                        }

                        Err(e) => {
                            let _ = self.event_tx.send(
                                TransportEvent::Error(
                                    3,
                                    format!("framing error: {}", e),
                                )
                            );
                        }
                    }
                }

                Err(e) => {
                    match e.kind() {
                        std::io::ErrorKind::WouldBlock
                        | std::io::ErrorKind::TimedOut
                        | std::io::ErrorKind::Interrupted => {}

                        _ => {
                            let _ = self.event_tx.send(
                                TransportEvent::Error(
                                    4,
                                    e.to_string(),
                                )
                            );

                            let _ = self.event_tx.send(
                                TransportEvent::State(
                                    TransportState::Disconnected as i32
                                )
                            );

                            return;
                        }
                    }
                }
            }

            thread::sleep(Duration::from_millis(1));
        }
    }
}

/// Internal connection context.
pub struct Connection {
    config: TransportConfig,
    #[allow(dead_code)]
    retry: RetryPolicy,

    command_tx: RefCell<Option<mpsc::Sender<TransportCommand>>>,

    worker: RefCell<Option<JoinHandle<()>>>,
}

impl Connection {
    pub fn new(
        config: TransportConfig,
        retry: RetryPolicy,
    ) -> Self {
        Self {
            config,
            retry,
            command_tx: RefCell::new(None),
            worker: RefCell::new(None),
        }
    }

    pub fn connect_sync(
        &mut self,
        event_tx: EventSender,
    ) -> Result<String> {
        let _ = event_tx.send(
            TransportEvent::State(
                TransportState::Connecting as i32
            )
        );

        let (host, port) = dns::resolve_xmpp(
            &self.config.host,
            self.config.port,
            self.config.service.as_deref(),
            self.config.use_ipv6,
        )?;

        let timeout = self.config.connect_timeout();

        let stream = match self.config.kind {
            TransportKind::DirectTls => {
                let tls =
                    tls::connect_direct(&host, port, false)?;

                StreamKind::Tls(tls)
            }

            TransportKind::Tcp | TransportKind::TcpStartTls => {
                let addr = format!("{}:{}", host, port);

                let mut addrs = addr
                    .to_socket_addrs()
                    .map_err(|e| {
                        HandshakeError::Connection(
                            e.to_string()
                        )
                    })?;

                let first = addrs.next().ok_or_else(|| {
                    HandshakeError::Connection(
                        "no address".into()
                    )
                })?;

                let tcp = TcpStream::connect_timeout(
                    &first,
                    timeout,
                )
                .map_err(|e| {
                    HandshakeError::Connection(
                        e.to_string()
                    )
                })?;

                let _ = tcp.set_nonblocking(true);
                let _ = tcp.set_write_timeout(
                    Some(Duration::from_secs(10))
                );

                StreamKind::Tcp(tcp)
            }

            TransportKind::WebSocket => {
                let addr = format!("{}:{}", host, port);

                let mut addrs = addr
                    .to_socket_addrs()
                    .map_err(|e| {
                        HandshakeError::Connection(
                            e.to_string()
                        )
                    })?;

                let first = addrs.next().ok_or_else(|| {
                    HandshakeError::Connection(
                        "no address".into()
                    )
                })?;

                let tcp = TcpStream::connect_timeout(
                    &first,
                    timeout,
                )
                .map_err(|e| {
                    HandshakeError::Connection(
                        e.to_string()
                    )
                })?;

                let path = self
                    .config
                    .ws_path
                    .as_deref()
                    .unwrap_or("/ws");

                let mut ws =
                    websocket::connect_websocket(
                        &host,
                        port,
                        path,
                        tcp,
                    )?;

                let _ = ws.set_tcp_nonblocking(true);

                StreamKind::Ws(ws)
            }

            TransportKind::WebSocketTls => {
                let tls_stream =
                    tls::connect_direct(
                        &host,
                        port,
                        false,
                    )?;

                let path = self
                    .config
                    .ws_path
                    .as_deref()
                    .unwrap_or("/ws");

                let ws =
                    websocket::connect_websocket_tls(
                        &host,
                        port,
                        path,
                        tls_stream,
                    )?;

                StreamKind::WsTls(ws)
            }
        };

        let (command_tx, command_rx) =
            mpsc::channel::<TransportCommand>();

        let worker = TransportWorker {
            host: host.clone(),
            stream,
            command_rx,
            event_tx: event_tx.clone(),
            framer: StreamFramer::new(),
        };

        let handle = thread::spawn(move || {
            worker.run();
        });

        *self.command_tx.borrow_mut() =
            Some(command_tx);

        *self.worker.borrow_mut() =
            Some(handle);

        let _ = event_tx.send(
            TransportEvent::State(
                TransportState::Connected as i32
            )
        );

        Ok(host)
    }

    pub fn send(
        &self,
        data: &[u8],
    ) -> Result<()> {
        match self.command_tx.borrow().as_ref() {
            Some(tx) => {
                tx.send(
                    TransportCommand::Send(
                        data.to_vec(),
                    )
                )
                .map_err(|_| {
                    HandshakeError::Connection(
                        "transport closed".into(),
                    )
                })?;

                Ok(())
            }

            None => Err(
                HandshakeError::Connection(
                    "not connected".into(),
                )
            ),
        }
    }

    pub fn shutdown(&self) {
        if let Some(tx) =
            self.command_tx.borrow().as_ref()
        {
            let _ = tx.send(
                TransportCommand::Shutdown
            );
        }
    }
}

impl Drop for Connection {
    fn drop(&mut self) {
        self.shutdown();

        if let Some(handle) =
            self.worker.borrow_mut().take()
        {
            let _ = handle.join();
        }
    }
}
