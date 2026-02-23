//! Whixp transport: TLS connection, polling, WebSocket, retry, handshake errors, stanza framing.
//! Dart resolves DNS and passes (host, port); this crate does the rest.
//! FFI layer for use from Dart via `dart:ffi`.

#![allow(clippy::missing_safety_doc)]

pub mod config;
pub mod connection;
pub mod dns;
pub mod handshake;
pub mod retry;
pub mod stanza;
pub mod tls;
pub mod websocket;

use std::os::raw::c_char;
use std::sync::Mutex;

use config::{TransportConfig, TransportKind};
use connection::{Connection, TransportEvent};
use handshake::HandshakeErrorCode;
use retry::RetryPolicy;

/// Opaque handle. Dart stores this and passes back to every FFI call.
pub struct Handle {
    connection: Mutex<Option<Connection>>,
    event_rx: Mutex<Option<std::sync::mpsc::Receiver<TransportEvent>>>,
    pending: Mutex<Option<TransportEvent>>,
    /// Resolved host after connect (for SASL/service name).
    resolved_host: Mutex<Option<String>>,
    /// Last connect error message when connect returns non-OK.
    last_error: Mutex<Option<String>>,
}

/// C-compatible config. host = domain to resolve; service = SRV name (e.g. xmpp-client) or null.
/// ws_path = WebSocket path (e.g. "/ws") or null to use default "/ws".
#[repr(C)]
pub struct CTransportConfig {
    pub host_ptr: *const c_char,
    pub host_len: u32,
    pub port: u16,
    pub kind: i32,
    pub connect_timeout_ms: u32,
    pub tls_server_name_ptr: *const c_char,
    pub tls_server_name_len: u32,
    pub service_ptr: *const c_char,
    pub service_len: u32,
    pub use_ipv6: i32,
    pub ws_path_ptr: *const c_char,
    pub ws_path_len: u32,
}

fn kind_from_c(k: i32) -> TransportKind {
    match k {
        0 => TransportKind::Tcp,
        1 => TransportKind::TcpStartTls,
        2 => TransportKind::DirectTls,
        3 => TransportKind::WebSocket,
        4 => TransportKind::WebSocketTls,
        _ => TransportKind::TcpStartTls,
    }
}

unsafe fn ptr_to_string(ptr: *const c_char, len: u32) -> String {
    if ptr.is_null() || len == 0 {
        return String::new();
    }
    let slice = std::slice::from_raw_parts(ptr as *const u8, len as usize);
    String::from_utf8_lossy(slice).into_owned()
}

/// Create a transport handle. Returns null on failure.
/// No callbacks; Dart polls for events via whixp_transport_poll.
#[no_mangle]
pub unsafe extern "C" fn whixp_transport_create(config: *const CTransportConfig) -> *mut Handle {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        if config.is_null() {
            return std::ptr::null_mut();
        }
        let c = &*config;
        let host = ptr_to_string(c.host_ptr as *const c_char, c.host_len);
        let tls_sni = if c.tls_server_name_ptr.is_null() {
            None
        } else {
            Some(ptr_to_string(
                c.tls_server_name_ptr as *const c_char,
                c.tls_server_name_len,
            ))
        };
        let service = if c.service_ptr.is_null() || c.service_len == 0 {
            None
        } else {
            Some(ptr_to_string(c.service_ptr as *const c_char, c.service_len))
        };
        let use_ipv6 = c.use_ipv6 != 0;
        let ws_path = if c.ws_path_ptr.is_null() || c.ws_path_len == 0 {
            Some("/ws".to_string())
        } else {
            Some(ptr_to_string(c.ws_path_ptr as *const c_char, c.ws_path_len))
        };
        let config = TransportConfig {
            host,
            port: c.port,
            kind: kind_from_c(c.kind),
            connect_timeout_ms: c.connect_timeout_ms,
            tls_server_name: tls_sni,
            service,
            use_ipv6,
            ws_path,
        };
        let retry = RetryPolicy::default();
        let connection = Connection::new(config, retry);
        let handle = Handle {
            connection: Mutex::new(Some(connection)),
            event_rx: Mutex::new(None),
            pending: Mutex::new(None),
            resolved_host: Mutex::new(None),
            last_error: Mutex::new(None),
        };
        Box::into_raw(Box::new(handle))
    }));
    result.unwrap_or(std::ptr::null_mut())
}

/// Connect. Creates event channel and starts I/O threads. Returns 0 on success, else HandshakeErrorCode.
/// Panics are caught so we never unwind across FFI (which would abort the process).
#[no_mangle]
pub unsafe extern "C" fn whixp_transport_connect(handle: *mut Handle) -> i32 {
    let result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        if handle.is_null() {
            return HandshakeErrorCode::Connection as i32;
        }
        let handle_ref = &*handle;
        if let Ok(mut last_err) = handle_ref.last_error.lock() {
            *last_err = None;
        }
        let (event_tx, event_rx) = std::sync::mpsc::channel();
        if let Ok(mut rx_guard) = handle_ref.event_rx.lock() {
            *rx_guard = Some(event_rx);
        }
        let mut guard = match handle_ref.connection.lock() {
            Ok(g) => g,
            Err(_) => return HandshakeErrorCode::Connection as i32,
        };
        let conn = match guard.as_mut() {
            Some(c) => c,
            None => return HandshakeErrorCode::Connection as i32,
        };
        match conn.connect_sync(event_tx) {
            Ok(resolved_host) => {
                if let Ok(mut r) = handle_ref.resolved_host.lock() {
                    *r = Some(resolved_host);
                }
                HandshakeErrorCode::Ok as i32
            }
            Err(e) => {
                if let Ok(mut last_err) = handle_ref.last_error.lock() {
                    *last_err = Some(e.to_string());
                }
                let code: HandshakeErrorCode = (&e).into();
                code as i32
            }
        }
    }));
    result.unwrap_or(HandshakeErrorCode::Connection as i32)
}

/// Poll next event. Call from Dart main isolate only.
/// Returns: 0 = none, 1 = state (call whixp_transport_get_polled_state), 2 = stanza (call whixp_transport_get_polled_stanza then whixp_transport_poll_clear), 3 = error (call whixp_transport_get_polled_error then whixp_transport_poll_clear).
#[no_mangle]
pub unsafe extern "C" fn whixp_transport_poll(handle: *mut Handle) -> i32 {
    if handle.is_null() {
        return 0;
    }
    let handle = &*handle;
    let mut pending = match handle.pending.lock() {
        Ok(p) => p,
        Err(_) => return 0,
    };
    if pending.is_none() {
        if let Ok(rx_guard) = handle.event_rx.lock() {
            if let Some(ref rx) = *rx_guard {
                if let Ok(ev) = rx.try_recv() {
                    *pending = Some(ev);
                }
            }
        }
    }
    match pending.as_ref() {
        Some(TransportEvent::State(_)) => 1,
        Some(TransportEvent::Stanza(_)) => 2,
        Some(TransportEvent::Error(_, _)) => 3,
        None => 0,
    }
}

/// Clear current pending event so next poll returns the next one.
#[no_mangle]
pub unsafe extern "C" fn whixp_transport_poll_clear(handle: *mut Handle) {
    if handle.is_null() {
        return;
    }
    if let Ok(mut pending) = (*handle).pending.lock() {
        *pending = None;
    }
}

/// Get polled state (only valid after poll returned 1). Returns state code.
#[no_mangle]
pub unsafe extern "C" fn whixp_transport_get_polled_state(handle: *mut Handle) -> i32 {
    if handle.is_null() {
        return 0;
    }
    if let Ok(pending) = (*handle).pending.lock() {
        if let Some(TransportEvent::State(s)) = *pending {
            return s;
        }
    }
    0
}

/// Get polled stanza (only valid after poll returned 2). Ptr valid until poll_clear.
#[no_mangle]
pub unsafe extern "C" fn whixp_transport_get_polled_stanza(
    handle: *mut Handle,
    out_ptr: *mut *const u8,
    out_len: *mut u32,
) {
    if handle.is_null() || out_ptr.is_null() || out_len.is_null() {
        return;
    }
    if let Ok(pending) = (*handle).pending.lock() {
        if let Some(TransportEvent::Stanza(ref s)) = *pending {
            *out_ptr = s.as_ptr();
            *out_len = s.len() as u32;
        }
    }
}

/// Get polled error (only valid after poll returned 3).
#[no_mangle]
pub unsafe extern "C" fn whixp_transport_get_polled_error(
    handle: *mut Handle,
    out_code: *mut i32,
    out_ptr: *mut *const u8,
    out_len: *mut u32,
) {
    if handle.is_null() || out_code.is_null() || out_ptr.is_null() || out_len.is_null() {
        return;
    }
    if let Ok(pending) = (*handle).pending.lock() {
        if let Some(TransportEvent::Error(code, ref msg)) = *pending {
            *out_code = code;
            *out_ptr = msg.as_ptr();
            *out_len = msg.len() as u32;
        }
    }
}

/// Send UTF-8 XML bytes. Dart encodes stanza to string then to UTF-8.
#[no_mangle]
pub unsafe extern "C" fn whixp_transport_send(
    handle: *mut Handle,
    data_ptr: *const u8,
    data_len: u32,
) -> i32 {
    if handle.is_null() || data_ptr.is_null() {
        return -1;
    }
    let handle = &*handle;
    let guard = match handle.connection.lock() {
        Ok(g) => g,
        Err(_) => return -1,
    };
    let conn = match guard.as_ref() {
        Some(c) => c,
        None => return -1,
    };
    let slice = std::slice::from_raw_parts(data_ptr, data_len as usize);
    match conn.send(slice) {
        Ok(()) => 0,
        Err(_) => -1,
    }
}

/// Disconnect and close socket.
#[no_mangle]
pub unsafe extern "C" fn whixp_transport_disconnect(handle: *mut Handle) {
    if handle.is_null() {
        return;
    }
    let handle = &*handle;
    if let Ok(guard) = handle.connection.lock() {
        if let Some(conn) = guard.as_ref() {
            conn.shutdown();
        }
    }
}

/// Get the resolved host after connect (for SASL/service name). Ptr valid until next connect or destroy.
#[no_mangle]
pub unsafe extern "C" fn whixp_transport_get_resolved_host(
    handle: *mut Handle,
    out_ptr: *mut *const u8,
    out_len: *mut u32,
) {
    if handle.is_null() || out_ptr.is_null() || out_len.is_null() {
        return;
    }
    if let Ok(guard) = (*handle).resolved_host.lock() {
        if let Some(ref s) = *guard {
            *out_ptr = s.as_ptr();
            *out_len = s.len() as u32;
        } else {
            *out_ptr = std::ptr::null();
            *out_len = 0;
        }
    }
}

/// Get last connect error message (when connect returned non-OK). Ptr valid until next connect or destroy.
#[no_mangle]
pub unsafe extern "C" fn whixp_transport_get_last_error(
    handle: *mut Handle,
    out_ptr: *mut *const u8,
    out_len: *mut u32,
) {
    if handle.is_null() || out_ptr.is_null() || out_len.is_null() {
        return;
    }
    if let Ok(guard) = (*handle).last_error.lock() {
        if let Some(ref s) = *guard {
            *out_ptr = s.as_ptr();
            *out_len = s.len() as u32;
        } else {
            *out_ptr = std::ptr::null();
            *out_len = 0;
        }
    }
}

/// Destroy handle and free memory. Call after disconnect.
#[no_mangle]
pub unsafe extern "C" fn whixp_transport_destroy(handle: *mut Handle) {
    if !handle.is_null() {
        let _ = Box::from_raw(handle);
    }
}
