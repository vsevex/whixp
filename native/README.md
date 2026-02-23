# Whixp native transport (Rust)

Transport, TLS, WebSocket, retry, handshake error handling, and stanza framing live in this Rust crate. **DNS resolving stays in Dart**; Dart passes resolved `(host, port)` to Rust.

## Build (maintainers)

Requires Rust (e.g. `rustup default stable`). From repo root:

```bash
cd native/whixp_transport
cargo build --release
```

TLS uses **rustls** (pure Rust); no OpenSSL or system crypto required for host builds.

**Cross-compilation:**

- **Windows** from Mac/Linux: `rustup target add x86_64-pc-windows-gnu` and install MinGW (e.g. macOS: `brew install mingw-w64`), then `make windows`.
- **Android / iOS**: use `cargo ndk`, `cross`, or CI.

## Output

- **cdylib** for Dart FFI: `libwhixp_transport.so` (Linux, Android), `libwhixp_transport.dylib` (macOS, iOS), `whixp_transport.dll` (Windows).
- These are placed into the Flutter plugin platform folders so that **users only need `pub get`** — no Rust toolchain required. CI should build for all targets and commit (or publish) the artifacts.

## Layout

- `whixp_transport/` — Cargo package
  - `src/config.rs` — host, port, TLS/WS, timeouts (filled by Dart after DNS)
  - `src/connection.rs` — connect, send, receive loop, disconnect
  - `src/tls.rs` — direct TLS and StartTLS upgrade
  - `src/websocket.rs` — WebSocket transport (stub)
  - `src/retry.rs` — backoff and retry policy
  - `src/handshake.rs` — handshake/stream error types
  - `src/stanza.rs` — stream framing (split bytes into stanza XML strings)
  - `src/lib.rs` — C FFI for Dart

## Dart side

- DNS: remains in Dart (e.g. `dnsolve`). After resolution, Dart calls `whixp_transport_create` with host/port.
- High-level API (handlers, events, send queue, batching) stays in Dart; Rust only does connection + polling + stanza framing and reports back via callbacks.

## Testing (why “Rust side” doesn’t fix the kill)

`dart test` can kill the process when the native lib is loaded inside the test runner (OOM or isolate limits). The Rust crate does **no work at library load**: Tokio runtime is created on first DNS use, rustls on first TLS use. So the kill is from **loading** the (large)
dylib in that environment, not from Rust code running at load.

- **Intended fix:** Dart does not load the native lib when it detects the test runner; Transport tests are skipped. Normal `dart test` / `make test` passes without loading the dylib.
- **Run Transport tests with native lib:**  
  `WHIXP_TEST_NATIVE=1 dart test test/transport_test.dart`  
  If it still gets killed, try more heap:  
  `DART_VM_OPTIONS="--old_gen_heap_size=2048" WHIXP_TEST_NATIVE=1 dart test test/transport_test.dart`
- **Shrinking the dylib** (fewer deps / features) could reduce OOM risk when loaded in test, but the robust approach is to keep “don’t load in test” on the Dart side.
