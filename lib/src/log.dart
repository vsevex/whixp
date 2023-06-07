import 'package:logger/logger.dart';

/// [Log] message type.
enum LogType { verbose, info, warn, error, fatal }

/// This class provides `logging` functionality using the `logger` package.
class Log {
  factory Log() => _instance;

  Log._();

  static final Log _instance = Log._();

  /// Final decleration of [Logger] class with the use of `logger` package.
  final _logger = Logger();

  /// The initializer (late) for enabling or disabling debugging option for
  /// whole package.
  late final bool debugEnabled;

  /// Calls only at the beginning of the main method.
  Log initialize({required bool debugEnabled}) {
    this.debugEnabled = debugEnabled;

    /// Return [Log], just in case.
    return Log();
  }

  /// Logs a message with a verbosity level of `verbose`.
  void _verbose(String message) => _logger.v(message);

  /// Logs a message with a verbosity level of `info`.
  void _info(String message) => _logger.i(message);

  /// Logs a message with a verbosity level of `warning`.
  void _warn(String message) => _logger.w(message);

  /// Logs a message with a verbosity level of `error`.
  void _error(String message) => _logger.e(message);

  /// Logs a message with a verbosity level of `fatal`.
  void _fatal(String message) => _logger.wtf(message);

  /// The main logger method. Decides which type of logger to use.
  void trigger(LogType type, String message) {
    /// Check if debugging enabled. If not enabled, then do not print anything.
    if (debugEnabled) {
      switch (type) {
        case LogType.verbose:
          _verbose(message);
        case LogType.info:
          _info(message);
        case LogType.warn:
          _warn(message);
        case LogType.error:
          _error(message);
        case LogType.fatal:
          _fatal(message);
      }
    }
  }
}
