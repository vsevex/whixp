import 'package:logger/logger.dart';

/// Sets up debugging for [Whixp] || [Transport] instance.
///
/// Configures debugging by attaching event listeners to log various types of
/// messages. Different types of messages (info, status, error) can be enabled
/// or disabled.
///
/// See also:
///
/// - [Logger], the logger instance used for logging messages.
/// - [PrettyPrinter], a pretty printer configuration for the logger.
class Log {
  static late Log _internal;

  /// A singleton class that provides configurable logging levels.
  factory Log({
    /// Whether to enable debug messages. Defaults to `true`
    bool enableDebug = true,

    /// Whether to enable info messages. Defaults to `true`
    bool enableInfo = true,

    /// Whether to enable error messages. Defaults to `false`
    bool enableError = false,

    /// Whether to enable warning messages. Defaults to `false`
    bool enableWarning = false,
  }) =>
      _internal = Log._firstInstance(
        enableDebug,
        enableInfo,
        enableError,
        enableWarning,
      );

  Log._firstInstance(
    this._enableDebug,
    this._enableInfo,
    this._enableError,
    this._enableWarning,
  );

  /// [Log] instance.
  static Log get instance => _internal;

  /// The underlying logger instance used for logging.
  late final _logger = Logger(
    printer: PrettyPrinter(
      lineLength: 250,
      printTime: true,
      methodCount: 0,
      noBoxingByDefault: true,
    ),
  );

  /// Whether to enable debugging message. Defaults to `true`.
  final bool _enableDebug;

  /// Whether to enable info message debugging. Defaults to `true`.
  final bool _enableInfo;

  /// Whether to enable error message debugging. Defaults to `false`.
  final bool _enableError;

  /// Whether to enable warning message debugging. Defaults to `false`.
  final bool _enableWarning;

  /// Logs an informational message if info logging is enabled.
  void info(String info) {
    if (_enableInfo) {
      _logger.i(info);
    }
  }

  /// Logs a debugging message if debug logging is enabled.
  void debug(String debug) {
    if (_enableDebug) {
      _logger.d(debug);
    }
  }

  /// Logs an error message if error logging is enabled.
  ///
  /// Optionally, you can provide an [error] object and [stackTrace].
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (_enableError) {
      _logger.e(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Logs a warning message if warning logging is enabled.
  void warning(String warning) {
    if (_enableWarning) {
      _logger.w(warning);
    }
  }
}
