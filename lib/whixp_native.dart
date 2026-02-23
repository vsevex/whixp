/// Optional native (Rust) transport for Whixp.
///
/// Import this only when you want to use the Rust transport layer.
/// DNS stays in Dart; Rust handles TLS, polling, WebSocket, retry, handshake errors, stanza framing.
/// See [doc/NATIVE_TRANSPORT.md](https://github.com/vsevex/whixp/blob/main/doc/NATIVE_TRANSPORT.md).
library;

export 'src/native/transport_ffi.dart';
