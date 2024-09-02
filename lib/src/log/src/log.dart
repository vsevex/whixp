import 'dart:io';

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
    final timestampPen = AnsiPen()..red(bold: true);
    late final AnsiPen logPen;

    /// There is an issue in the logging when the application is trying to built
    /// to iOS. So, for now, do not use colorized output on iOS.
    ///
    /// Take a look: https://github.com/flutter/flutter/issues/64491
    final isIOS = Platform.isIOS;

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
          logPen = AnsiPen()..rgb(r: 1, g: .2, b: 0);
        case Level.error:
          logPen = AnsiPen()..red();
        case Level.warning:
          logPen = AnsiPen()..rgb(r: 1, g: .5, b: 0);
        case Level.info:
          logPen = AnsiPen()..green(bold: true);
        case Level.debug:
          logPen = AnsiPen()..blue();
        case Level.verbose:
          break;
      }
    }

    final timestamp = instance._includeTimestamp
        ? isIOS
            ? ' --${_timestamp(instance._showDate)}-- '
            : ' ${timestampPen.call(_timestamp(instance._showDate))} '
        : ' ';

    // ignore: avoid_print
    print('[Whixp]$timestamp${isIOS ? logsStr : logPen(logsStr)}');
  }
}

/// Pen attributes for foreground and background colors.
class AnsiPen {
  /// Treat a pen instance as a function such that `pen('msg')` is the same as
  /// `pen.write('msg')`.
  String call(Object msg) => write(msg);

  /// Allow pen colors to be used in a string.
  ///
  /// Note: Once the pen is down, its attributes remain in effect till they are
  ///     changed by another pen or [up].
  @override
  String toString() {
    if (!_dirty) return _pen;

    final sb = StringBuffer();
    if (_fcolor != -1) {
      sb.write('${ansiEscape}38;5;${_fcolor}m');
    }

    if (_bcolor != -1) {
      sb.write('${ansiEscape}48;5;${_bcolor}m');
    }

    _dirty = false;
    return sb.toString();
  }

  /// Returns control codes to change the terminal colors.
  String get down => '$this';

  /// Resets all pen attributes in the terminal.
  String get up => ansiDefault;

  /// Write the [msg.toString()] with the pen's current settings and then
  /// reset all attributes.
  String write(Object msg) => '$this$msg$up';

  void black({bool bg = false, bool bold = false}) => _std(0, bold, bg);
  void red({bool bg = false, bool bold = false}) => _std(1, bold, bg);
  void green({bool bg = false, bool bold = false}) => _std(2, bold, bg);
  void yellow({bool bg = false, bool bold = false}) => _std(3, bold, bg);
  void blue({bool bg = false, bool bold = false}) => _std(4, bold, bg);
  void magenta({bool bg = false, bool bold = false}) => _std(5, bold, bg);
  void cyan({bool bg = false, bool bold = false}) => _std(6, bold, bg);
  void white({bool bg = false, bool bold = false}) => _std(7, bold, bg);

  /// Sets the pen color to the rgb value between 0.0..1.0.
  void rgb({num r = 1.0, num g = 1.0, num b = 1.0, bool bg = false}) => xterm(
        (r.clamp(0.0, 1.0) * 5).toInt() * 36 +
            (g.clamp(0.0, 1.0) * 5).toInt() * 6 +
            (b.clamp(0.0, 1.0) * 5).toInt() +
            16,
        bg: bg,
      );

  /// Sets the pen color to a grey scale value between 0.0 and 1.0.
  void gray({num level = 1.0, bool bg = false}) =>
      xterm(232 + (level.clamp(0.0, 1.0) * 23).round(), bg: bg);

  void _std(int color, bool bold, bool bg) =>
      xterm(color + (bold ? 8 : 0), bg: bg);

  /// Directly index the xterm 256 color palette.
  void xterm(int color, {bool bg = false}) {
    _dirty = true;
    final c = color < 0
        ? 0
        : color > 255
            ? 255
            : color;
    if (bg) {
      _bcolor = c;
    } else {
      _fcolor = c;
    }
  }

  /// Resets the pen's attributes.
  void reset() {
    _dirty = false;
    _pen = '';
    _bcolor = _fcolor = -1;
  }

  /// Returns the pen's foreground color
  int get fcolor => _fcolor;

  /// Returns the pen's background color index.
  int get bcolor => _bcolor;

  /// Returns whether the pen's attributes are dirty.
  bool get dirty => _dirty;

  int _fcolor = -1;
  int _bcolor = -1;
  String _pen = '';
  bool _dirty = false;
}

/// ANSI Control Sequence Introducer, signals the terminal for new settings.
const ansiEscape = '\x1B[';

/// Reset all colors and options for current SGRs to terminal defaults.
const ansiDefault = '${ansiEscape}0m';

/// Ansi codes that default the terminal's foreground color without
/// altering the background, when printed.
///
/// Does not modify [AnsiPen]!
const ansiResetForeground = '${ansiEscape}39m';

///Ansi codes that default the terminal's background color without
///altering the foreground, when printed.
///
/// Does not modify [AnsiPen]!
const ansiResetBackground = '${ansiEscape}49m';
