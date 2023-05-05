import 'package:logger/logger.dart';

/// This class provides `logging` functionality using the `logger` package.
class Log {
  /// Returns instance of this class.
  factory Log() => _instance;

  /// Private constructor declared for the creation of instance.
  Log._();

  /// Instance variable which returns private [Log] private constructor.
  static final Log _instance = Log._();

  /// Final decleration of [Logger] class with the use of `logger` package.
  final logger = Logger();

  /// Logs a message with a verbosity level of `verbose`.
  void log(String message) => logger.v(message);

  /// Logs a message with a verbosity level of `info`.
  void info(String message) => logger.i(message);

  /// Logs a message with a verbosity level of `warning`.
  void warn(String message) => logger.w(message);

  /// Logs a message with a verbosity level of `error`.
  void error(String message) => logger.e(message);

  /// Logs a message with a verbosity level of `fatal`.
  void fatal(String message) => logger.wtf(fatal);
}
