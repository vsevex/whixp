import 'dart:io' as io;

import 'package:whixp/src/exception.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/socket/socket_listener.dart';

/// Connection type for socket connections.
enum ConnectionType {
  /// Plain TCP connection without TLS.
  tcp,

  /// Direct TLS connection from the start.
  tls,

  /// TCP connection that can be upgraded to TLS later.
  upgradableTcp,
}

/// Manages socket connections using pure Dart dart:io classes.
///
/// This class replaces the Connecta package functionality and provides:
/// - Plain TCP connections
/// - Direct TLS connections
/// - TCP to TLS upgrades (StartTLS)
class SocketManager {
  /// Creates a [SocketManager] with the specified configuration.
  SocketManager({
    required this.hostname,
    required this.port,
    required this.connectionType,
    required this.listener,
    this.securityContext,
    this.timeout,
    this.onBadCertificateCallback,
    this.supportedProtocols = const ['TLSv1.2', 'TLSv1.3'],
  });

  /// The hostname to connect to.
  final String hostname;

  /// The port to connect to.
  final int port;

  /// The type of connection to establish.
  final ConnectionType connectionType;

  /// The listener for socket events.
  final SocketListener listener;

  /// Optional security context for TLS connections.
  final io.SecurityContext? securityContext;

  /// Connection timeout in milliseconds.
  final int? timeout;

  /// Callback for handling bad certificates.
  final bool Function(io.X509Certificate cert)? onBadCertificateCallback;

  /// Supported TLS protocols.
  final List<String> supportedProtocols;

  io.Socket? _socket;
  io.SecureSocket? _secureSocket;
  bool _isSecure = false;
  bool _isDestroyed = false;
  final List<int> _buffer = [];

  /// The underlying socket (TCP or SecureSocket).
  dynamic get socket => _secureSocket ?? _socket;

  /// Whether the connection is secure (TLS).
  bool get isConnectionSecure => _isSecure;

  /// Whether the socket manager has been destroyed.
  bool get isDestroyed => _isDestroyed;

  /// Creates a connection and establishes the socket.
  ///
  /// The connection is established immediately. To cancel, use [destroy()].
  Future<void> createTask(
    SocketListener listener,
  ) async {
    if (_isDestroyed) {
      throw SocketManagerException(
        'Socket manager has been destroyed',
      );
    }

    final duration = timeout != null
        ? Duration(milliseconds: timeout!)
        : const Duration(seconds: 30);

    try {
      switch (connectionType) {
        case ConnectionType.tcp:
          _socket = await io.Socket.connect(
            hostname,
            port,
            timeout: duration,
          ).timeout(duration);

          _setupSocket(_socket!);
          Log.instance.info(
            'TCP socket connected to ${_socket!.remoteAddress}:${_socket!.remotePort}',
          );

        case ConnectionType.tls:
          _secureSocket = await io.SecureSocket.connect(
            hostname,
            port,
            context: securityContext,
            timeout: duration,
            onBadCertificate: onBadCertificateCallback,
            supportedProtocols: supportedProtocols,
          ).timeout(duration);
          _isSecure = true;

          _setupSecureSocket(_secureSocket!);
          Log.instance.info(
            'TLS socket connected to ${_secureSocket!.remoteAddress}:${_secureSocket!.remotePort}',
          );

        case ConnectionType.upgradableTcp:
          _socket = await io.Socket.connect(
            hostname,
            port,
            timeout: duration,
          ).timeout(duration);

          _setupSocket(_socket!);
          Log.instance.info(
            'TCP socket connected (upgradable) to ${_socket!.remoteAddress}:${_socket!.remotePort}',
          );
      }

      // Connection established successfully
      // To cancel, use destroy() method
    } catch (e) {
      // Clean up on error
      _socket?.close();
      _secureSocket?.close();
      _socket = null;
      _secureSocket = null;

      if (e is io.SocketException || e is io.TlsException) {
        throw SocketManagerException(
          'Failed to connect to $hostname:$port: $e',
        );
      }
      if (e is SocketManagerException) {
        rethrow;
      }
      throw SocketManagerException(
        'Unexpected error connecting to $hostname:$port: $e',
      );
    }
  }

  /// Upgrades a TCP connection to TLS (StartTLS).
  ///
  /// This method should only be called when [connectionType] is
  /// [ConnectionType.upgradableTcp] and a TCP connection is already established.
  Future<void> upgradeConnection(SocketListener listener) async {
    if (_isDestroyed) {
      throw SocketManagerException('Socket manager has been destroyed');
    }

    if (_socket == null) {
      throw SocketManagerException('No TCP socket available for upgrade');
    }

    if (_isSecure) {
      throw SocketManagerException('Connection is already secure');
    }

    if (connectionType != ConnectionType.upgradableTcp) {
      throw SocketManagerException(
        'Connection type does not support upgrade: $connectionType',
      );
    }

    try {
      final duration = timeout != null
          ? Duration(milliseconds: timeout!)
          : const Duration(seconds: 30);

      // Upgrade the socket to TLS
      _secureSocket = await io.SecureSocket.secure(
        _socket!,
        host: hostname,
        context: securityContext,
        onBadCertificate: onBadCertificateCallback,
        supportedProtocols: supportedProtocols,
      ).timeout(duration);

      // Close the old TCP socket
      await _socket?.close();
      _socket = null;

      _isSecure = true;
      _setupSecureSocket(_secureSocket!);

      Log.instance.info('Successfully upgraded connection to TLS');
    } catch (e) {
      Log.instance.error('TLS upgrade failed: $e');
      throw SocketManagerException(
        'Failed to upgrade connection to TLS: $e',
      );
    }
  }

  /// Sends data through the socket.
  void send(List<int> data) {
    if (_isDestroyed) {
      Log.instance.warning('Attempted to send data on destroyed socket');
      return;
    }

    try {
      if (_secureSocket != null) {
        _secureSocket!.add(data);
      } else if (_socket != null) {
        _socket!.add(data);
      } else {
        Log.instance.warning('No socket available for sending data');
        throw SocketManagerException('No socket available for sending data');
      }
    } on io.SocketException catch (e, stackTrace) {
      Log.instance.error(
        'Socket error while sending data: $e - socket may be closed',
      );
      listener.onError(e, stackTrace);
    } catch (e, stackTrace) {
      Log.instance.error('Error sending data: $e');
      listener.onError(e, stackTrace);
    }
  }

  /// Destroys the socket and cleans up resources.
  void destroy() {
    if (_isDestroyed) return;

    _isDestroyed = true;

    try {
      _secureSocket?.close();
      _socket?.close();
    } catch (e) {
      Log.instance.warning('Error closing socket: $e');
    } finally {
      _secureSocket = null;
      _socket = null;
      _buffer.clear();
    }
  }

  void _setupSocket(io.Socket socket) {
    // Store a flag to track if we've sent the initial stream header
    // This helps distinguish between immediate closure vs normal closure
    bool connectionEstablished = false;

    // Set a small delay to mark connection as established
    // This helps us detect if the server closes immediately
    Future.delayed(const Duration(milliseconds: 100), () {
      connectionEstablished = true;
    });

    socket.listen(
      (data) {
        if (_isDestroyed) return;

        _buffer.addAll(data);

        // Check if we should continue combining data
        if (listener.combineWhile(_buffer)) {
          // Continue buffering
          return;
        }

        // Process the buffered data
        final dataToProcess = List<int>.from(_buffer);
        _buffer.clear();
        listener.onData(dataToProcess);
      },
      onError: (error, stackTrace) {
        if (!_isDestroyed) {
          Log.instance.error(
            'Socket error: $error (${error.runtimeType})',
          );
          listener.onError(error as Object, stackTrace as StackTrace);
        }
      },
      onDone: () {
        if (!_isDestroyed) {
          if (!connectionEstablished) {
            Log.instance.error(
              'Socket closed immediately after connection - server may require TLS or rejected the connection',
            );
          } else {
            Log.instance.warning(
              'Socket connection closed (onDone callback fired)',
            );
          }
          listener.onDone();
        }
      },
      cancelOnError: false,
    );
  }

  void _setupSecureSocket(io.SecureSocket socket) {
    // Store a flag to track if we've sent the initial stream header
    bool connectionEstablished = false;

    // Set a small delay to mark connection as established
    Future.delayed(const Duration(milliseconds: 100), () {
      connectionEstablished = true;
    });

    socket.listen(
      (data) {
        if (_isDestroyed) return;

        _buffer.addAll(data);

        // Check if we should continue combining data
        if (listener.combineWhile(_buffer)) {
          // Continue buffering
          return;
        }

        // Process the buffered data
        final dataToProcess = List<int>.from(_buffer);
        _buffer.clear();
        listener.onData(dataToProcess);
      },
      onError: (error, stackTrace) {
        if (!_isDestroyed) {
          Log.instance.error(
            'Secure socket error: $error (${error.runtimeType})',
          );
          listener.onError(error as Object, stackTrace as StackTrace);
        }
      },
      onDone: () {
        if (!_isDestroyed) {
          if (!connectionEstablished) {
            Log.instance.error(
              'Secure socket closed immediately after connection - server may have rejected the connection',
            );
          } else {
            Log.instance.warning(
              'Secure socket connection closed (onDone callback fired)',
            );
          }
          listener.onDone();
        }
      },
      cancelOnError: false,
    );
  }
}

/// Exception thrown by SocketManager for connection-related errors.
class SocketManagerException extends WhixpException {
  /// Creates a [SocketManagerException] with the given [message].
  SocketManagerException(super.message);
}
