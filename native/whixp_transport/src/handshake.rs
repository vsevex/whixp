//! Handshake and stream error handling: TLS errors, stream:error, see-other-host.
//! Surfaces to Dart as error codes and messages so Dart can drive UI or retry.

use thiserror::Error;

/// Errors that can occur during connection or stream handshake.
#[derive(Error, Debug)]
pub enum HandshakeError {
    #[error("connection failed: {0}")]
    Connection(String),

    #[error("TLS handshake failed: {0}")]
    Tls(String),

    #[error("stream error: {0}")]
    Stream(String),

    #[error("timeout after {0}ms")]
    Timeout(u64),

    #[error("see-other-host: {0}")]
    SeeOtherHost(String),

    #[error("invalid certificate: {0}")]
    BadCertificate(String),
}

/// C-friendly error code for FFI.
#[repr(C)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum HandshakeErrorCode {
    Ok = 0,
    Connection = 1,
    Tls = 2,
    Stream = 3,
    Timeout = 4,
    SeeOtherHost = 5,
    BadCertificate = 6,
}

impl From<&HandshakeError> for HandshakeErrorCode {
    fn from(e: &HandshakeError) -> Self {
        match e {
            HandshakeError::Connection(_) => HandshakeErrorCode::Connection,
            HandshakeError::Tls(_) => HandshakeErrorCode::Tls,
            HandshakeError::Stream(_) => HandshakeErrorCode::Stream,
            HandshakeError::Timeout(_) => HandshakeErrorCode::Timeout,
            HandshakeError::SeeOtherHost(_) => HandshakeErrorCode::SeeOtherHost,
            HandshakeError::BadCertificate(_) => HandshakeErrorCode::BadCertificate,
        }
    }
}
