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

## Package size (managing native libs)

**If your binary is 30+ MB you are almost certainly building debug.** Use `cargo build --release` and check the file in `target/release/` (e.g. `libwhixp_transport.so`). With the release profile you should see roughly **3–10 MB** per target.

Release builds use a size-oriented profile (`opt-level = "z"`, LTO, strip, `panic = "abort"`, single-threaded tokio runtime). For an even smaller binary, build without the DoH fallback: `cargo build --release --no-default-features` (system DNS only; no ureq). Tokio + rustls + TLS still add several MB per target.

**Ways to manage size as a package:**

1. **Don't commit built libs** — Add to repo `.gitignore`: `macos/*.dylib`, `linux/*.so`, `windows/*.dll`, `android/src/main/jniLibs/`, `ios/*.a`. Document that users run `make` (or `make android` / `make ios` etc.) for their platform. Pub package stays small; downside: users need Rust/NDK/Xcode for their target.

2. **Commit only what you need** — e.g. commit only `macos/` and `linux/` for desktop-only; leave Android/iOS to "build from source" in the README.

3. **Android: ship fewer ABIs** — In your app's `android/app/build.gradle`, set `ndk.abiFilters` so the APK only includes ABIs you need (e.g. `abiFilters 'arm64-v8a'` for most devices; add `armeabi-v7a`, `x86_64` only for 32-bit or emulator). The Makefile builds all three by default; you can build one ABI and put it in `jniLibs` for a smaller app.

4. **CI builds, optional publish** — Build all targets in CI and attach artifacts to releases. Package on pub.dev stays source-only; power users get prebuilt libs from GitHub Releases.

## How users get the binaries (after `pub get`)

**Option A — Binaries included in the package (default if we commit them)**  
If the published package on pub.dev includes the built libs (e.g. `macos/`, `linux/`, `windows/`, `android/.../jniLibs/`, `ios/`), then **`flutter pub get` or `dart pub get` is enough**: the native libraries are already in the package. No extra steps.

**Option B — Download from GitHub Releases**  
If the package does _not_ ship binaries (to keep pub small), maintainers attach a zip to each [GitHub Release](https://github.com/vsevex/whixp/releases) (e.g. `whixp-native-v3.1.0.zip`). Users:

1. Run `pub get` as usual.
2. Download `whixp-native-<version>.zip` from the [Releases](https://github.com/vsevex/whixp/releases) page for the version they use.
3. Unzip and copy the contents into the package’s platform folders (e.g. copy `macos/` into `.../whixp/macos/`, `android/` into `.../whixp/android/src/main/jniLibs/`, etc.). The zip layout matches the repo layout.

Releases are created automatically when you push a tag `v*` (e.g. `v3.1.0`); the [Native builds](.github/workflows/native.yml) workflow builds all platforms and attaches the zip.

**Option C — Build from source**  
Users with Rust (and for Android: NDK; for iOS: Xcode) can build locally. From the **package root** (e.g. inside their pub cache or a cloned repo):

- **Current host only:** `make` or `make release`
- **macOS:** `make macos`
- **Linux:** `make linux` (on Linux) or `make linux-cross` / `make linux-cross-docker` (from Mac)
- **Windows:** `make windows`
- **Android:** set `ANDROID_NDK_HOME` then `make android`
- **iOS:** `make ios` (on macOS with Xcode)

Then the built libs are in `macos/`, `linux/`, `windows/`, `android/src/main/jniLibs/`, `ios/` as above.
