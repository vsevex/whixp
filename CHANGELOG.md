# 3.1.0

## Added

- **Native (Rust) transport**: Optional Rust-based transport for TCP, TLS, WebSocket, and stanza framing
  - TLS via **rustls** (no OpenSSL); DNS resolution remains in Dart
  - **WebSocket**: `useWebSocket: true` and optional `wsPath` (e.g. `"/ws"`) on `Transport` / `Whixp`; native layer uses tungstenite for `ws://` and `wss://`
  - Prebuilt libs for macOS, Linux, Windows, Android, iOS (see `native/README.md`, `make help`)
  - Dart FFI layer in `lib/src/native/transport_ffi.dart`; optional entrypoint `package:whixp/whixp_native.dart`
  - When the native lib is present, `Transport` uses it; otherwise construction throws with a clear message
- **Makefile**: Build and copy native libs (`make`, `make macos`, `make linux`, `make windows`, etc.) and run tests (`make test`)

## Changed

- **Transport**: Uses the native (Rust) transport when the library is available on the current platform
  - Connection, TLS/StartTLS, retry, and stanza framing are handled in Rust; batching, rate limiting, and high-level API stay in Dart
- **Tests**: `dart_test.yaml` sets `concurrency: 1` to reduce memory pressure when running the full suite

## Removed

- **Dart socket layer**: Replaced by the native transport
  - Removed `lib/src/socket/socket_listener.dart` and `lib/src/socket/socket_manager.dart`

## Fixed

- **Test runner kill (SIGKILL)**: `dart test` could kill the process when loading the native lib in test isolates
  - Native lib is **not** loaded when the test runner is detected (script path or env); Transport tests are skipped unless `WHIXP_TEST_NATIVE=1`
  - Run all tests: `dart test` or `make test` (Transport tests skipped; no native load)
  - Run Transport tests with native: `WHIXP_TEST_NATIVE=1 dart test test/transport_test.dart` (optional: `DART_VM_OPTIONS="--old_gen_heap_size=2048"` if OOM)

## Documentation

- **native/README.md**: Build instructions, layout, Dart integration, and a “Testing” section explaining why the native lib is not loaded under `dart test` and how to run Transport tests with the native lib
- **Makefile**: Inline comments for test and heap-size usage

---

## 3.0.0

> **Note**: This is a major version release with significant improvements and breaking changes. See [UPGRADE_STEPS.md](UPGRADE_STEPS.md) for detailed upgrade instructions.

## Major Release

This version represents a significant modernization of Whixp, focusing on improved architecture, better testability, and enhanced XMPP protocol support.

### Breaking Changes

_This section will be updated as breaking changes are implemented during the upgrade process._

- **Transport Singleton Removed**: `Transport` no longer uses singleton pattern
  - **Migration**: If you were accessing `Transport.instance()`, you now need to use the instance passed to `WhixpBase`
  - **Impact**: This allows multiple XMPP connections in the same application
  - **Example**:

    ```dart
    // Before (v2.x)
    Transport.instance().send(stanza);

    // After (v3.0)
    whixp.send(stanza); // Use Whixp instance methods
    ```

- **IQ.send() Now Requires Transport**: The `IQ.send()` method now requires a `Transport` parameter as the first argument
  - **Migration**: Update all `iq.send()` calls to pass the transport instance
  - **Example**:

    ```dart
    // Before (v2.x)
    final result = await iq.send();

    // After (v3.0)
    final result = await iq.send(transport); // or whixp.transport
    ```

- **Session Constructor Changed**: `Session` now requires a `Transport` parameter
- **Migration**: If creating Session directly, pass transport: `Session(features, transport)`
- **Impact**: Internal change, typically not used directly by end users
- **SDK Requirement**: Minimum Dart SDK version increased to 3.3.0
- **Legacy vCard Support Removed**: Removed all `vcard-temp` (XEP-0054) support
  - Removed `vCardTag` constant (legacy vCard tag)
  - Removed `VCARD` namespace constant from utils
  - **Migration**: Use vCard4 over PubSub (XEP-0292) instead via `PubSub.retrieveVCard()`, `PubSub.publishVCard()`, etc.
  - **Impact**: Any code using legacy vCard constants will need to migrate to vCard4

### Added (3.0.0)

- **Performance Optimizations**: Added comprehensive performance improvements for high-volume applications
  - **Message Batching**: Automatically batches outgoing stanzas to reduce network overhead
    - Configurable batch size (default: 50 stanzas) and delay (default: 100ms)
    - Critical stanzas (IQ, SASL, SM) are sent immediately without batching
    - Can be enabled/disabled via `enableBatching` parameter
  - **Rate Limiting**: Token bucket algorithm to prevent overwhelming the server
    - Configurable rate limit (default: 100 stanzas/second) and burst size (default: 50)
    - Automatically throttles sending when rate limit is exceeded
    - Can be enabled/disabled via `enableRateLimiting` parameter
  - **Bounded Queues**: Configurable queue size limits to prevent memory issues
    - Default maximum queue size: 1000 stanzas
    - Backpressure handling when queue is full
    - Can be set to `null` for unbounded queue (not recommended for production)
  - **Performance Configuration**: New Transport constructor parameters:

```dart
    Transport(
      'example.com',
      enableBatching: true,
      maxBatchSize: 50,
      maxBatchDelay: 100,
      enableRateLimiting: true,
      maxStanzasPerSecond: 100,
      maxBurst: 50,
      maxQueueSize: 1000,
    );
```

- **CLI Messenger Example**: Added comprehensive CLI messaging tool demonstrating v3.0 features
  - Interactive command-line interface for XMPP messaging
  - Real-time performance metrics display
  - TLS configuration options for local development
  - Command-line flags: `--no-tls`, `--direct-tls`, `--accept-bad-cert`, `--port`
  - Better error handling and connection state management
  - See `example/cli_messenger.dart` and `example/README_CLI.md`
- **TLS Configuration Documentation**: Added comprehensive TLS configuration guide
  - Explains StartTLS, DirectTLS, and plain TCP modes
  - Common TLS errors and solutions
  - Dart/Flutter TLS limitations
  - Best practices for production and local development
  - ejabberd configuration examples
  - See `docs/TLS_CONFIGURATION.md`
- **XML Parsing Optimizations**: Added parsing optimization utilities
  - `ParsingOptimizations` class with helper methods to reduce redundant operations
    - `getElementChildren()`: Caches element children to avoid multiple iterations
    - `findFirstChild()` / `findChildren()`: Efficiently find children by local name
    - `getCachedInnerText()`: Optimized text extraction
    - Reduces allocations and improves parsing performance for high-volume applications
    - **Note**: These utilities are available for use but current parsing is already optimized
- **Performance Metrics**: Added comprehensive performance monitoring system
  - `PerformanceMetrics` class for tracking client performance
    - Stanzas sent/received/parsed counts and rates
    - Batch statistics (sizes, flush times, frequencies)
    - Rate limiter statistics (hits, throttling events)
    - Queue statistics (current size, max size, overflows)
    - Parsing performance (average parsing time)
    - Real-time metrics with `getSummary()` and `getFormattedSummary()`
    - Accessible via `Transport.metrics` property
    - Metrics automatically reset on connection start
  - **Usage Example**:

````dart
    final transport = Transport('example.com');
    // ... use transport ...
    print(transport.metrics.getFormattedSummary());
    // Or get structured data:
    final summary = transport.metrics.getSummary();
    print('Stanzas sent: ${summary['stanzasSent']}');
    print('Average parsing time: ${summary['averageParsingTimeMs']}ms');
```
- **Test Coverage**: Added comprehensive tests for performance modules
  - `test/rate_limiter_test.dart`: Tests for rate limiting functionality
    - Token bucket algorithm behavior
    - Rate limiting enable/disable
    - Token replenishment over time
    - Concurrent access handling
    - Edge cases (zero rate, high rate, low rate)
  - `test/batcher_test.dart`: Tests for message batching functionality
    - Batching behavior (size-based and time-based)
    - Critical packet immediate sending (IQ, SASL, SM)
    - Enable/disable functionality
    - Flush and dispose operations
    - Concurrent access handling
    - Edge cases (empty batch, small/large batch sizes)

### Changed

- **SDK Requirement**: Minimum Dart SDK version increased from 3.2.5 to 3.3.0
- **Dependencies**: Updated dependencies to latest compatible versions:
  - `dnsolve`: Updated to ^2.0.0
  - `synchronized`: Updated to ^3.4.0
  - `unorm_dart`: Updated to ^0.3.2
  - `xml`: Updated to ^6.6.1
- **Testing**: Added `coverage` package (^1.8.0) for test coverage reporting
- **Async Patterns**: Standardized async/await patterns throughout the codebase
  - Replaced `Future.microtask()` with direct async/await where possible
  - Simplified timeout handling by removing unnecessary `runZonedGuarded` calls
  - Improved error propagation in async operations
  - **Note**: Behavior should be the same, but error handling is more consistent
- **Error Handling**: Improved error messages and recovery mechanisms
  - Enhanced exception classes with error codes and recovery suggestions
  - More descriptive error messages with context (host, port, mechanism names, etc.)
  - Better error context in connection establishment (includes connection details)
  - Improved authentication error messages with mechanism information
  - Enhanced timeout error messages with timeout duration
  - Better error logging throughout critical paths
  - Improved reconnection logic with informative messages
  - **Note**: Error behavior is unchanged, but messages are more helpful for debugging

### Removed

- **Legacy vCard Support**: Removed all `vcard-temp` (XEP-0054) support
  - Removed `vCardTag` constant (legacy vCard tag)
  - Removed `VCARD` namespace constant from utils
  - **Migration**: Use vCard4 over PubSub (XEP-0292) instead via `PubSub.retrieveVCard()`, `PubSub.publishVCard()`, etc.
  - **Impact**: Any code using legacy vCard constants will need to migrate to vCard4

- **Commented Code**: Removed commented-out deprecated code
  - Removed `_database.dart` file with commented Hive database code
  - Cleaned up commented code in command plugin

### Fixed

_This section will be updated as bugs are fixed during the upgrade process._

### Documentation

- Updated README with "Why Use Whixp" section
- Added platform support clarification (no web support)
- Added limitations section (OMEMO not supported)

---

## 2.1.3

- **MongooseIM**
  - Add [Inbox](https://esl.github.io/MongooseDocs/latest/open-extensions/inbox/) plugin support

## 2.1.2+1

- **Documentation**
  - The documentation now includes several pages translated into Azerbaijani.

## 2.1.2 - 2024-09-24

- **Documentation**
  - The documentation [page](https://dosyllc.github.io/whixpdoc/)
- **Bug Fixes**
  - Fixed small bugs related to anonymous server connections.

## 2.1.1 - 2024-09-02

- **Added**
  - Message Archive Management (MAM) Support: Implemented support for the MAM extension allowing users to archive and retrieve
  chat history more effectively.
  - Displayed Markers Support: Added functionality to handle displayed markers, improving message tracking and read
  receipt features.

- **Fixed**
  - Stream Management: Resolved issues related to resource binding conflicts that occurred without clearing the previous
  connection, enhancing overall stability and reliability.

## 2.1.0 - 2024-08-20

- Removed External Components Support: The external components section has been removed to streamline the core package
functionality. If you rely on components, refer to the provided examples and code documentation for updated usage patterns.
- Updated Documentation: Expanded documentation to cover new extension support and breaking changes. Refer to the
updated examples for proper implementation of new features and adjustments.

- **Breaking Changes**
  - External Components: The support for external components has been deprecated and removed. If you were using this
  feature, you will need to refactor your implementation. Updated examples are provided in the documentation to guide
  you through these changes.\
  - Protocol Extensions: Some existing extensions have undergone refactoring to align with the new architecture. Users
  should review their implementation of protocol extensions and refer to the updated documentation and examples to
  ensure compatibility.
  - Connection Management and Stanza Handling: The internal handling of connection states and stanzas has been revised.
  Users may need to update their event handling logic, particularly around connection re-establishment and custom stanza
  handling.

- **Deprecated**
  - Legacy vCard Support: The legacy vCard _(vCard-temp)_ support has been deprecated in favor of **vCard4 over PubSub**.
  Users are encouraged to migrate to the new implementation for better performance and flexibility.

- **Documentation**
  - Migration Guide: Included a migration guide in the documentation to help users transition from older versions to
  this release.

Ensure that you review the updated examples and documentation to adjust your implementation accordingly. If you encounter
any issues, please report them via GitHub, and I will address them promptly.

## 2.0.1 - Partially Stable

- Added support for XMPP components.
- Added extension support to pubsub, pep, vcard-temp, and in-band registration as well as tune, ping, delay, stream
management, etc.
- Provided more reliable communication using Dart Sockets.
- Changed certificate assignment from explicit to `dart:io`'s SecureContext
- Provided more Whixp-related examples and use cases.

## 2.0.1-beta1 - 2024-01-23

Everything is changed. I mean, literally everything. Can not even put it all into words, especially in here. So, go ahead
and give it a try.

But remember, the package is still in beta and not quite ready for stable usage. Please consider this while exploring
the new features and improvements. Your feedbacks and bug reports are highly appreciated to help me
refine the package for a stable release.

## 0.1.0 - 2023-09-14

## Breaking

- **Event System Overhaul**
  The main eventing system has undergone a significant change. Previously, it used a static approach, but now it utilizes
  the 'EventsEmitter' class for event handling. This change may require updates to your event handling code.

  Please refer to the updated documentation for guidance on using the new event system.

## Deprecated

- **Extension Systems and Extensions Removal**
  The previously created extension systems and extensions have been deprecated in this release and will be
  entirely removed in the next release.

  It is recommended to prepare for this change by migrating your extensions to the new system that will be introduced in
  the upcoming version. Detailed instructions will be provided in the next release's documentation.

## 0.0.7 - 2023-08-08

- Added `CAPS` extension support.
- Added `Roster` extension support.

## 0.0.6 - 2023-07-18

- Added `Disco` extension support.
- Added `Registration` extension support.

## 0.0.55 - 2023-07-08

- Added Extension Attachment support.
- Added `vCard` support.
- Added `pubsub` support.

### Fixed (v0.0.55)

- Resolved various bugs that were affecting the stability and performance of the XMPP client.
- Improved error handling and messaging reliability.

## 0.0.5 - 2023-06-07

- Improved WebSocket connectivity for better reliability and performance.
- Enhanced exception handling to provide more informative error messages.
- Expanded the main constructor by adding a new parameter: `debugEnabled`.

## 0.0.1 - 2023-05-31

- Initial release of the `EchoX`.
- WebSocket connectivity to XMPP servers.
- Authentication mechanisms including `SASL-SCRAM` with SHA-1, PLAIN, and SHA-256.
- Basic XMPP protocol numbers for reference.
- Utility methods for common XMPP tasks.
- Tested on Openfire XMPP server.
````
