import 'package:echo/src/echo.dart';
import 'package:echo/src/echotils/echotils.dart';
import 'package:echo/src/error/error.dart';
import 'package:echo/src/mishaps.dart';

import 'package:logger/logger.dart';

/// Sets up debugging for [Echo] instance.
///
/// Configures debugging for an [Echo] instance by attaching event listeners
/// to log various types of messages. Different types of messages (info,
/// status, error) can be enabled or disabled.
///
/// Example:
/// ```dart
/// final echo = Echo();
/// debug(echo, enableInfo: false);
/// ```
///
/// See also:
///
/// - [Logger], the logger instance used for logging messages.
/// - [PrettyPrinter], a pretty printer configuration for the logger.
void debug(
  /// The [Echo] instance for which debugging is enabled.
  Echo echo, {
  /// Whether to enable info message debugging. Defaults to `true`.
  bool enableInfo = true,

  /// Whether to enable status message debugging. Defaults to `true`.
  bool enableStatus = true,

  /// Whether to enable error message debugging. Defaults to `false`.
  bool enableError = false,
}) {
  late final logger = Logger(
    printer: PrettyPrinter(
      lineLength: 250,
      printTime: true,
      methodCount: 0,
      noBoxingByDefault: true,
    ),
  );

  if (enableInfo) {
    echo.on<String>('info', (info) {
      logger.d(info);
    });
  }

  if (enableStatus) {
    echo.on<StatusEmitter>('status', (status) {
      logger.w(status);
    });
  }

  if (enableError) {
    echo.on<Mishap>('error', (mishap) {
      if (mishap is WebSocketMishap) {
        logger.t(mishap, error: mishap.error);
      } else {
        logger.e(mishap);
      }
    });
  }
}
