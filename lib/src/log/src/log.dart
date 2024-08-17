enum Level {
  wtf,
  error,
  warning,
  info,
  debug,
  verbose,
}

/// Sets up debugging for [Whixp] || [Transport] instance.
///
/// Configures debugging by attaching event listeners to log various types of
/// messages. Different types of messages (info, status, error) can be enabled
/// or disabled.
class Log {
  static late Log _internal;

  /// [Log] instance.
  static Log get instance => _internal;

  factory Log({
    /// Whether to enable debug messages. Defaults to `true`
    bool enableDebug = true,

    /// Whether to enable info messages. Defaults to `true`
    bool enableInfo = true,

    /// Whether to enable error messages. Defaults to `false`
    bool enableError = false,

    /// Whether to enable warning messages. Defaults to `false`
    bool enableWarning = false,

    /// Whether to use native colors assigned to level types or not.
    bool nativeColors = true,

    /// Whether to add date and time indicator in the log message or not.
    bool includeTimestamp = false,

    /// Whether to show date in the log output or not.
    bool showDate = false,
  }) =>
      _internal = Log._firstInstance(
        enableDebug,
        enableInfo,
        enableError,
        enableWarning,
        nativeColors,
        includeTimestamp,
        showDate,
      );

  /// A singleton class that provides configurable logging levels.
  Log._firstInstance(
    this._enableDebug,
    this._enableInfo,
    this._enableError,
    this._enableWarning,
    this._nativeColors,
    this._includeTimestamp,
    this._showDate,
  );

  /// Whether to enable debugging message. Defaults to `true`.
  final bool _enableDebug;

  /// Whether to enable info message debugging. Defaults to `true`.
  final bool _enableInfo;

  /// Whether to enable error message debugging. Defaults to `false`.
  final bool _enableError;

  /// Whether to enable warning message debugging. Defaults to `false`.
  final bool _enableWarning;

  final bool _includeTimestamp;

  final bool _showDate;

  /// Override this function if you want to convert a stacktrace for some reason
  /// for example to apply a source map in the browser.
  static StackTrace? Function(StackTrace?) stackTraceConverter = (s) => s;

  final bool _nativeColors;

  final List<LogEvent> outputEvents = [];

  void addLogEvent(LogEvent logEvent) {
    if (logEvent.level == Level.error && _enableError ||
        logEvent.level == Level.warning && _enableWarning ||
        logEvent.level == Level.info && _enableInfo ||
        logEvent.level == Level.debug && _enableDebug) {
      outputEvents.add(logEvent);
      logEvent.printOut();
    }
  }

  void error(String title, {Object? exception, StackTrace? stackTrace}) {
    addLogEvent(
      LogEvent(
        title,
        exception: exception,
        stackTrace: stackTraceConverter(stackTrace),
        level: Level.error,
      ),
    );
  }

  void warning(String title, [Object? exception, StackTrace? stackTrace]) {
    if (_enableWarning) {
      addLogEvent(
        LogEvent(
          title,
          exception: exception,
          stackTrace: stackTraceConverter(stackTrace),
          level: Level.warning,
        ),
      );
    }
  }

  void info(String title, [Object? exception, StackTrace? stackTrace]) {
    if (_enableInfo) {
      addLogEvent(
        LogEvent(
          title,
          exception: exception,
          stackTrace: stackTraceConverter(stackTrace),
          level: Level.info,
        ),
      );
    }
  }

  void debug(String title, [Object? exception, StackTrace? stackTrace]) {
    if (_enableDebug) {
      addLogEvent(
        LogEvent(
          title,
          exception: exception,
          stackTrace: stackTraceConverter(stackTrace),
        ),
      );
    }
  }
}

// ignore: avoid_print
class LogEvent {
  final String title;
  final Object? exception;
  final StackTrace? stackTrace;
  final Level level;

  LogEvent(
    this.title, {
    this.exception,
    this.stackTrace,
    this.level = Level.debug,
  });
}

String _timestamp(bool showDate) {
  final now = DateTime.now();

  final formattedDate = 'dd/MM/yyyy'
      .replaceAll('yyyy', now.year.toString().padLeft(4, '0'))
      .replaceAll('MM', now.month.toString().padLeft(2, '0'))
      .replaceAll('dd', now.day.toString().padLeft(2, '0'));

  final formattedTime =
      '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.millisecond.toString().padLeft(3, '0')}';
  return '${showDate ? '$formattedDate ' : ''}$formattedTime';
}

extension PrintLogs on LogEvent {
  void printOut() {
    final instance = Log.instance;
    var logsStr = title;
    if (exception != null) {
      logsStr += ' - $exception';
    }

    if (stackTrace != null) {
      logsStr += '\n$stackTrace';
    }
    if (instance._nativeColors) {
      switch (level) {
        case Level.wtf:
          logsStr = '\x1B[31m!!!CRITICAL!!! $logsStr\x1B[0m';
        case Level.error:
          logsStr = '\x1B[31m$logsStr\x1B[0m';
        case Level.warning:
          logsStr = '\x1B[33m$logsStr\x1B[0m';
        case Level.info:
          logsStr = '\x1B[32m$logsStr\x1B[0m';
        case Level.debug:
          logsStr = '\x1B[34m$logsStr\x1B[0m';
        case Level.verbose:
          break;
      }
    }

    final timestamp = '\x1B[35;40m${_timestamp(instance._showDate)}\x1B[0m';

    // ignore: avoid_print
    print('[Whixp]${instance._includeTimestamp ? ' $timestamp' : ''} $logsStr');
  }
}
