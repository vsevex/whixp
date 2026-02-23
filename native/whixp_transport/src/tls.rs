//! TLS connection and StartTLS upgrade.
//! Uses rustls (pure Rust) so Windows cross-build needs no MinGW/OpenSSL.

use std::io::{Read, Write};
use std::net::TcpStream;
use std::sync::{Arc, Once};

use rustls::pki_types::ServerName;
use rustls::ClientConfig;
use thiserror::Error;
use webpki_roots::TLS_SERVER_ROOTS;

/// Install rustls crypto provider once (no Rust main in cdylib). Only run when TLS is used.
static RUSTLS_INIT: Once = Once::new();

fn ensure_rustls_provider() {
    RUSTLS_INIT.call_once(|| {
        let _ = rustls::crypto::ring::default_provider().install_default();
    });
}

use crate::handshake::HandshakeError;

#[derive(Error, Debug)]
pub enum TlsError {
    #[error("rustls: {0}")]
    Rustls(#[from] rustls::Error),
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
}

/// Wrapper around a TLS stream (TcpStream + rustls).
pub struct TlsStreamWrapper {
    inner: rustls::StreamOwned<rustls::ClientConnection, TcpStream>,
}

impl Read for TlsStreamWrapper {
    fn read(&mut self, buf: &mut [u8]) -> std::io::Result<usize> {
        self.inner.read(buf)
    }
}

impl Write for TlsStreamWrapper {
    fn write(&mut self, buf: &[u8]) -> std::io::Result<usize> {
        self.inner.write(buf)
    }
    fn flush(&mut self) -> std::io::Result<()> {
        self.inner.flush()
    }
}

fn make_config_default_roots() -> Result<ClientConfig, TlsError> {
    ensure_rustls_provider();
    let mut root_store = rustls::RootCertStore::empty();
    root_store.extend(TLS_SERVER_ROOTS.iter().cloned());
    Ok(ClientConfig::builder()
        .with_root_certificates(root_store)
        .with_no_client_auth())
}

/// Accepts any server certificate (for testing / bad-cert callback from Dart).
#[derive(Debug)]
struct AllowAnyVerifier;

impl rustls::client::danger::ServerCertVerifier for AllowAnyVerifier {
    fn verify_server_cert(
        &self,
        _end_entity: &rustls::pki_types::CertificateDer,
        _intermediates: &[rustls::pki_types::CertificateDer],
        _server_name: &rustls::pki_types::ServerName<'_>,
        _ocsp_response: &[u8],
        _now: rustls::pki_types::UnixTime,
    ) -> Result<rustls::client::danger::ServerCertVerified, rustls::Error> {
        Ok(rustls::client::danger::ServerCertVerified::assertion())
    }

    fn verify_tls12_signature(
        &self,
        _message: &[u8],
        _cert: &rustls::pki_types::CertificateDer<'_>,
        _dss: &rustls::DigitallySignedStruct,
    ) -> Result<rustls::client::danger::HandshakeSignatureValid, rustls::Error> {
        Ok(rustls::client::danger::HandshakeSignatureValid::assertion())
    }

    fn verify_tls13_signature(
        &self,
        _message: &[u8],
        _cert: &rustls::pki_types::CertificateDer<'_>,
        _dss: &rustls::DigitallySignedStruct,
    ) -> Result<rustls::client::danger::HandshakeSignatureValid, rustls::Error> {
        Ok(rustls::client::danger::HandshakeSignatureValid::assertion())
    }

    fn supported_verify_schemes(&self) -> Vec<rustls::SignatureScheme> {
        vec![
            rustls::SignatureScheme::RSA_PKCS1_SHA256,
            rustls::SignatureScheme::ECDSA_NISTP256_SHA256,
            rustls::SignatureScheme::ED25519,
        ]
    }
}

fn make_config_allow_invalid() -> ClientConfig {
    ensure_rustls_provider();
    ClientConfig::builder()
        .dangerous()
        .with_custom_certificate_verifier(Arc::new(AllowAnyVerifier))
        .with_no_client_auth()
}

/// Connect to host:port over TLS (direct TLS).
pub fn connect_direct(
    host: &str,
    port: u16,
    accept_bad_cert: bool,
) -> Result<TlsStreamWrapper, HandshakeError> {
    let tcp =
        TcpStream::connect((host, port)).map_err(|e| HandshakeError::Connection(e.to_string()))?;
    let config = if accept_bad_cert {
        make_config_allow_invalid()
    } else {
        make_config_default_roots().map_err(|e| HandshakeError::Tls(e.to_string()))?
    };
    let server_name: ServerName<'static> = ServerName::try_from(host.to_string())
        .map_err(|_| HandshakeError::Tls("invalid server name".into()))?;
    let conn = rustls::ClientConnection::new(Arc::new(config), server_name)
        .map_err(|e| HandshakeError::Tls(e.to_string()))?;
    let stream = rustls::StreamOwned::new(conn, tcp);
    Ok(TlsStreamWrapper { inner: stream })
}

/// Upgrade existing TCP stream to TLS (StartTLS).
pub fn upgrade_tcp(
    tcp: TcpStream,
    host: &str,
    accept_bad_cert: bool,
) -> Result<TlsStreamWrapper, HandshakeError> {
    let config = if accept_bad_cert {
        make_config_allow_invalid()
    } else {
        make_config_default_roots().map_err(|e| HandshakeError::Tls(e.to_string()))?
    };
    let server_name: ServerName<'static> = ServerName::try_from(host.to_string())
        .map_err(|_| HandshakeError::Tls("invalid server name".into()))?;
    let conn = rustls::ClientConnection::new(Arc::new(config), server_name)
        .map_err(|e| HandshakeError::Tls(e.to_string()))?;
    let stream = rustls::StreamOwned::new(conn, tcp);
    Ok(TlsStreamWrapper { inner: stream })
}
