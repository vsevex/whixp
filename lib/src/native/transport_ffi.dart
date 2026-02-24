// ignore_for_file: non_constant_identifier_names

/// transport_ffi.dart
library;

/// FFI bindings for the Rust transport layer.
///
/// DNS is resolved in Dart; then [WhixpTransportNative] is used to connect,
/// send, and receive. Rust handles TLS, polling, retry, handshake errors,
/// and stanza framing. Users `pub get` and use; prebuilt libs are in the
/// package (android/jniLibs, ios/, etc.).

import 'dart:async' as async;
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

// ignore: depend_on_referenced_packages
import 'package:whixp/src/exception.dart';
import 'package:whixp/src/log/log.dart';

// Concrete exception for native transport errors
class _NativeTransportException extends WhixpException {
  const _NativeTransportException(super.message);
}

/// Whether the native transport library was loaded. If false, use Dart transport.
/// Triggers load on first read so we actually try to find the Rust-built lib.
bool get isNativeTransportAvailable {
  _lib ??= _loadLib();
  return _lib != null;
}

DynamicLibrary? _lib;

// No callbacks from Rust threads; we poll from main isolate instead.

/// Load the native library. Called once; falls back to null if not found.
/// Tries the simple name first (app bundle / LD_LIBRARY_PATH), then the
/// package platform folder (e.g. macos/, linux/) when running via `dart run`.
/// When running under `dart test`, does not load the lib (avoids process kill
/// from native code in test isolates). Set WHIXP_TEST_NATIVE=1 to load anyway.
DynamicLibrary? _loadLib() {
  if (_lib != null) return _lib;
  try {
    final scriptPath = Platform.script.toFilePath();
    final inTest = scriptPath.contains('/test/') ||
        scriptPath.contains(r'\test\') ||
        scriptPath.contains('_test.dart') ||
        scriptPath.contains('dart_test') ||
        scriptPath.contains('runInIsolate') ||
        scriptPath.contains('.dart_tool');
    if (inTest && Platform.environment['WHIXP_TEST_NATIVE'] != '1') {
      return null;
    }
    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libwhixp_transport.so');
    } else if (Platform.isIOS) {
      _lib = DynamicLibrary.process();
    } else if (Platform.isMacOS) {
      _lib = _openByName('libwhixp_transport.dylib') ??
          _openFromAppBundle('libwhixp_transport.dylib') ??
          _openFromPackageRoot('macos', 'libwhixp_transport.dylib');
    } else if (Platform.isWindows) {
      _lib = _openByName('whixp_transport.dll') ??
          _openFromPackageRoot('windows', 'whixp_transport.dll');
    } else if (Platform.isLinux) {
      _lib = _openByName('libwhixp_transport.so') ??
          _openFromPackageRoot('linux', 'libwhixp_transport.so');
    }
    if (_lib == null) {
      Log.instance.warning(
          '[native transport] library not found; build with make/make macos');
    }
  } catch (e, st) {
    Log.instance.error('[native transport] load failed: $e');
    Log.instance.error('[native transport] $st');
    _lib = null;
  }
  return _lib;
}

DynamicLibrary? _openByName(String name) {
  try {
    return DynamicLibrary.open(name);
  } catch (_) {
    return null;
  }
}

/// Try to open the library from the package root. Tries: (1) one level up from
/// [Platform.script] dir (e.g. script = .../example/main.dart -> .../whixp/macos/),
/// (2) cwd and cwd/.. (e.g. when cwd is example/, try ../macos/...).
DynamicLibrary? _openFromPackageRoot(String platformDir, String libName) {
  final fromScript = _openFromScriptDir(platformDir, libName);
  if (fromScript != null) return fromScript;

  final cwd = Directory.current.path;
  for (final root in [cwd, path.dirname(cwd)]) {
    final libPath = path.join(root, platformDir, libName);
    try {
      if (File(libPath).existsSync()) {
        return DynamicLibrary.open(libPath);
      }
    } catch (_) {}
  }
  return null;
}

DynamicLibrary? _openFromScriptDir(String platformDir, String libName) {
  try {
    final scriptUri = Platform.script;
    if (!scriptUri.isScheme('file')) return null;
    final scriptPath = scriptUri.toFilePath();
    final scriptDir = path.dirname(scriptPath);
    final candidateRoot = path.dirname(scriptDir);
    final libPath = path.join(candidateRoot, platformDir, libName);
    if (File(libPath).existsSync()) {
      return DynamicLibrary.open(libPath);
    }
  } catch (_) {}
  return null;
}

/// On macOS, when running as a .app bundle, executable is in Contents/MacOS;
/// dylibs in Contents/Frameworks are on the search path. Try explicit path
/// in case the app embeds the whixp dylib there.
DynamicLibrary? _openFromAppBundle(String libName) {
  try {
    final executable = Platform.resolvedExecutable;
    final exeDir = path.dirname(executable);
    // e.g. .../cave.app/Contents/MacOS -> .../cave.app/Contents/Frameworks
    final frameworksDir = path.join(exeDir, '..', 'Frameworks');
    final libPath = path.join(frameworksDir, libName);
    if (File(libPath).existsSync()) {
      return DynamicLibrary.open(libPath);
    }
  } catch (_) {}
  return null;
}

/// Transport kind: 0=Tcp, 1=TcpStartTls, 2=DirectTls, 3=WebSocket, 4=WebSocketTls
const int kKindTcp = 0;
const int kKindTcpStartTls = 1;
const int kKindDirectTls = 2;
const int kKindWebSocket = 3;
const int kKindWebSocketTls = 4;

/// C config struct (Rust: CTransportConfig). host = domain to resolve; service = SRV name (e.g. xmpp-client) or null.
/// ws_path = WebSocket path (e.g. "/ws") or null for default "/ws".
final class CTransportConfig extends Struct {
  external Pointer<Utf8> host_ptr;
  @Uint32()
  external int host_len;
  @Uint16()
  external int port;
  @Int32()
  external int kind;
  @Uint32()
  external int connect_timeout_ms;
  external Pointer<Utf8> tls_server_name_ptr;
  @Uint32()
  external int tls_server_name_len;
  external Pointer<Utf8> service_ptr;
  @Uint32()
  external int service_len;
  @Int32()
  external int use_ipv6;
  external Pointer<Utf8> ws_path_ptr;
  @Uint32()
  external int ws_path_len;
}

/// Opaque handle
typedef TransportHandle = Pointer<Void>;
typedef _CreateNative = TransportHandle Function(
    Pointer<CTransportConfig> config);
typedef _ConnectNative = Int32 Function(TransportHandle handle);
typedef _SendNative = Int32 Function(
  TransportHandle handle,
  Pointer<Uint8> data_ptr,
  Uint32 data_len,
);
typedef _DisconnectNative = Void Function(TransportHandle handle);
typedef _DestroyNative = Void Function(TransportHandle handle);
typedef _PollNative = Int32 Function(TransportHandle handle);
typedef _PollClearNative = Void Function(TransportHandle handle);
typedef _GetPolledStateNative = Int32 Function(TransportHandle handle);
typedef _GetPolledStanzaNative = Void Function(
  TransportHandle handle,
  Pointer<Pointer<Uint8>> outPtr,
  Pointer<Uint32> outLen,
);
typedef _GetPolledErrorNative = Void Function(
  TransportHandle handle,
  Pointer<Int32> outCode,
  Pointer<Pointer<Uint8>> outPtr,
  Pointer<Uint32> outLen,
);
typedef _GetResolvedHostNative = Void Function(
  TransportHandle handle,
  Pointer<Pointer<Uint8>> outPtr,
  Pointer<Uint32> outLen,
);
typedef _GetLastErrorNative = Void Function(
  TransportHandle handle,
  Pointer<Pointer<Uint8>> outPtr,
  Pointer<Uint32> outLen,
);

Pointer<NativeFunction<_CreateNative>>? _createFn;
Pointer<NativeFunction<_ConnectNative>>? _connectFn;
Pointer<NativeFunction<_SendNative>>? _sendFn;
Pointer<NativeFunction<_DisconnectNative>>? _disconnectFn;
Pointer<NativeFunction<_DestroyNative>>? _destroyFn;
Pointer<NativeFunction<_PollNative>>? _pollFn;
Pointer<NativeFunction<_PollClearNative>>? _pollClearFn;
Pointer<NativeFunction<_GetPolledStateNative>>? _getPolledStateFn;
Pointer<NativeFunction<_GetPolledStanzaNative>>? _getPolledStanzaFn;
Pointer<NativeFunction<_GetPolledErrorNative>>? _getPolledErrorFn;
Pointer<NativeFunction<_GetResolvedHostNative>>? _getResolvedHostFn;
Pointer<NativeFunction<_GetLastErrorNative>>? _getLastErrorFn;

void _ensureBindings() {
  final lib = _loadLib();
  if (lib == null) {
    throw const _NativeTransportException(
        'Native transport library not available');
  }
  _createFn ??=
      lib.lookup<NativeFunction<_CreateNative>>('whixp_transport_create');
  _connectFn ??=
      lib.lookup<NativeFunction<_ConnectNative>>('whixp_transport_connect');
  _sendFn ??= lib.lookup<NativeFunction<_SendNative>>('whixp_transport_send');
  _disconnectFn ??= lib
      .lookup<NativeFunction<_DisconnectNative>>('whixp_transport_disconnect');
  _destroyFn ??=
      lib.lookup<NativeFunction<_DestroyNative>>('whixp_transport_destroy');
  _pollFn ??= lib.lookup<NativeFunction<_PollNative>>('whixp_transport_poll');
  _pollClearFn ??= lib
      .lookup<NativeFunction<_PollClearNative>>('whixp_transport_poll_clear');
  _getPolledStateFn ??= lib.lookup<NativeFunction<_GetPolledStateNative>>(
      'whixp_transport_get_polled_state');
  _getPolledStanzaFn ??= lib.lookup<NativeFunction<_GetPolledStanzaNative>>(
      'whixp_transport_get_polled_stanza');
  _getPolledErrorFn ??= lib.lookup<NativeFunction<_GetPolledErrorNative>>(
      'whixp_transport_get_polled_error');
  _getResolvedHostFn ??= lib.lookup<NativeFunction<_GetResolvedHostNative>>(
      'whixp_transport_get_resolved_host');
  _getLastErrorFn ??= lib.lookup<NativeFunction<_GetLastErrorNative>>(
      'whixp_transport_get_last_error');
}

/// High-level wrapper for the Rust transport. Events are polled from main isolate (no callbacks from Rust threads).
class WhixpTransportNative {
  WhixpTransportNative._(this._handle, this._sendPort);

  TransportHandle? _handle;
  final SendPort _sendPort;
  async.Timer? _pollTimer;

  /// Create transport (no callbacks). host = domain to resolve; Rust does SRV + connect.
  /// wsPath = WebSocket path (e.g. "/ws") or null for default "/ws"; only used when kind is WebSocket/WebSocketTls.
  static WhixpTransportNative? create({
    required String host,
    required int port,
    required int kind,
    int connectTimeoutMs = 2000,
    String? tlsServerName,
    String? service,
    bool useIPv6 = false,
    String? wsPath,
    required SendPort sendPort,
  }) {
    _loadLib();
    if (_lib == null) return null;
    _ensureBindings();
    final helper = _TransportConfigHelper();
    final config = helper.allocConfig(
      host,
      port,
      kind,
      connectTimeoutMs,
      tlsServerName,
      service,
      useIPv6,
      wsPath,
    );
    final handle = _createFn!
            .asFunction<TransportHandle Function(Pointer<CTransportConfig>)>()(
        config);
    helper.freeConfig(config);
    if (handle == nullptr) return null;
    return WhixpTransportNative._(handle, sendPort);
  }

  /// Connect (blocking). Returns 0 on success; else error code. Use [lastError] for message.
  int connect() {
    if (_handle == null) return -1;
    _ensureBindings();
    return _connectFn!.asFunction<int Function(TransportHandle)>()(_handle!);
  }

  /// Resolved host after connect (for SASL). Empty if not connected.
  String get resolvedHost {
    if (_handle == null) return '';
    _ensureBindings();
    final outPtr = calloc<Pointer<Uint8>>();
    final outLen = calloc<Uint32>();
    try {
      _getResolvedHostFn!.asFunction<
          void Function(TransportHandle, Pointer<Pointer<Uint8>>,
              Pointer<Uint32>)>()(_handle!, outPtr, outLen);
      final ptr = outPtr.value;
      final len = outLen.value;
      if (ptr != nullptr && len > 0) {
        return utf8.decode(ptr.asTypedList(len));
      }
    } finally {
      calloc.free(outPtr);
      calloc.free(outLen);
    }
    return '';
  }

  /// Last connect error message when [connect] returned non-zero.
  String get lastError {
    if (_handle == null) return '';
    _ensureBindings();
    final outPtr = calloc<Pointer<Uint8>>();
    final outLen = calloc<Uint32>();
    try {
      _getLastErrorFn!.asFunction<
          void Function(TransportHandle, Pointer<Pointer<Uint8>>,
              Pointer<Uint32>)>()(_handle!, outPtr, outLen);
      final ptr = outPtr.value;
      final len = outLen.value;
      if (ptr != nullptr && len > 0) {
        return utf8.decode(ptr.asTypedList(len));
      }
    } finally {
      calloc.free(outPtr);
      calloc.free(outLen);
    }
    return '';
  }

  /// Start polling for events and posting to [_sendPort]. Call from main isolate after [connect] succeeds.
  void startPolling() {
    if (_handle == null) return;
    _pollTimer?.cancel();
    _pollTimer = async.Timer.periodic(
      const Duration(milliseconds: 2),
      (_) => _drainPoll(),
    );
  }

  void _drainPoll() {
    if (_handle == null) return;
    _ensureBindings();
    final poll = _pollFn!.asFunction<int Function(TransportHandle)>()(_handle!);
    switch (poll) {
      case 0:
        return;
      case 1:
        final state = _getPolledStateFn!
            .asFunction<int Function(TransportHandle)>()(_handle!);
        _sendPort.send(['state', state]);
        _pollClearFn!.asFunction<void Function(TransportHandle)>()(_handle!);
      case 2:
        final outPtr = calloc<Pointer<Uint8>>();
        final outLen = calloc<Uint32>();
        try {
          _getPolledStanzaFn!.asFunction<
              void Function(TransportHandle, Pointer<Pointer<Uint8>>,
                  Pointer<Uint32>)>()(_handle!, outPtr, outLen);
          final ptr = outPtr.value;
          final len = outLen.value;
          if (ptr != nullptr && len > 0) {
            final list = ptr.asTypedList(len);
            _sendPort.send(['stanza', utf8.decode(list)]);
          }
        } finally {
          calloc.free(outPtr);
          calloc.free(outLen);
        }
        _pollClearFn!.asFunction<void Function(TransportHandle)>()(_handle!);
      case 3:
        final outCode = calloc<Int32>();
        final outPtr = calloc<Pointer<Uint8>>();
        final outLen = calloc<Uint32>();
        try {
          _getPolledErrorFn!.asFunction<
              void Function(
                  TransportHandle,
                  Pointer<Int32>,
                  Pointer<Pointer<Uint8>>,
                  Pointer<Uint32>)>()(_handle!, outCode, outPtr, outLen);
          final code = outCode.value;
          final ptr = outPtr.value;
          final len = outLen.value;
          final msg = (ptr != nullptr && len > 0)
              ? utf8.decode(ptr.asTypedList(len))
              : '';
          _sendPort.send(['error', code, msg]);
        } finally {
          calloc.free(outCode);
          calloc.free(outPtr);
          calloc.free(outLen);
        }
        _pollClearFn!.asFunction<void Function(TransportHandle)>()(_handle!);
    }
  }

  /// Send UTF-8 XML bytes.
  int send(Uint8List data) {
    if (_handle == null) return -1;
    _ensureBindings();
    final ptr = calloc<Uint8>(data.length);
    try {
      for (var i = 0; i < data.length; i++) {
        ptr[i] = data[i];
      }
      return _sendFn!
              .asFunction<int Function(TransportHandle, Pointer<Uint8>, int)>()(
          _handle!, ptr, data.length);
    } finally {
      malloc.free(ptr);
    }
  }

  void disconnect() {
    if (_handle == null) return;
    _pollTimer?.cancel();
    _pollTimer = null;
    _ensureBindings();
    _disconnectFn!.asFunction<void Function(TransportHandle)>()(_handle!);
  }

  void destroy() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_handle == null) return;
    _ensureBindings();
    _destroyFn!.asFunction<void Function(TransportHandle)>()(_handle!);
    _handle = null;
  }
}

/// Allocates config for create (no callbacks).
class _TransportConfigHelper {
  Pointer<Utf8>? _hostPtr;
  Pointer<Utf8>? _tlsPtr;
  Pointer<Utf8>? _servicePtr;
  Pointer<Utf8>? _wsPathPtr;

  Pointer<CTransportConfig> allocConfig(
    String host,
    int port,
    int kind,
    int connectTimeoutMs,
    String? tlsServerName,
    String? service,
    bool useIPv6,
    String? wsPath,
  ) {
    _hostPtr = host.toNativeUtf8();
    final hostLenBytes = utf8.encode(host).length;
    _tlsPtr = tlsServerName?.toNativeUtf8();
    final tlsLenBytes =
        tlsServerName != null ? utf8.encode(tlsServerName).length : 0;
    _servicePtr = service?.toNativeUtf8();
    final serviceLenBytes = service != null ? utf8.encode(service).length : 0;
    _wsPathPtr = wsPath?.toNativeUtf8();
    final wsPathLenBytes = wsPath != null ? utf8.encode(wsPath).length : 0;
    final config = calloc<CTransportConfig>();
    config.ref.host_ptr = _hostPtr!.cast();
    config.ref.host_len = hostLenBytes;
    config.ref.port = port;
    config.ref.kind = kind;
    config.ref.connect_timeout_ms = connectTimeoutMs;
    config.ref.tls_server_name_ptr = _tlsPtr?.cast() ?? nullptr.cast();
    config.ref.tls_server_name_len = tlsLenBytes;
    config.ref.service_ptr = _servicePtr?.cast() ?? nullptr.cast();
    config.ref.service_len = serviceLenBytes;
    config.ref.use_ipv6 = useIPv6 ? 1 : 0;
    config.ref.ws_path_ptr = _wsPathPtr?.cast() ?? nullptr.cast();
    config.ref.ws_path_len = wsPathLenBytes;
    return config;
  }

  void freeConfig(Pointer<CTransportConfig> config) {
    calloc.free(config);
    malloc.free(_hostPtr!);
    if (_tlsPtr != null) malloc.free(_tlsPtr!);
    if (_servicePtr != null) malloc.free(_servicePtr!);
    if (_wsPathPtr != null) malloc.free(_wsPathPtr!);
  }
}
