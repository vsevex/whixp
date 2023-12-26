// import 'package:echox/src/echotils/echotils.dart';
// import 'package:echox/src/echox.dart';
// import 'package:echox/src/error/error.dart';
// import 'package:echox/src/mishaps.dart';

// import 'package:logger/logger.dart';

// /// Sets up debugging for [EchoX] instance.
// ///
// /// Configures debugging for an [EchoX] instance by attaching event listeners
// /// to log various types of messages. Different types of messages (info,
// /// status, error) can be enabled or disabled.
// ///
// /// Example:
// /// ```dart
// /// final echox = EchoX();
// /// debug(echox, enableInfo: false);
// /// ```
// ///
// /// See also:
// ///
// /// - [Logger], the logger instance used for logging messages.
// /// - [PrettyPrinter], a pretty printer configuration for the logger.
// void debug(
//   /// The [EchoX] instance for which debugging is enabled.
//   EchoX echox, {
//   /// Whether to enable info message debugging. Defaults to `true`.
//   bool enableInfo = true,

//   /// Whether to enable status message debugging. Defaults to `true`.
//   bool enableStatus = true,

//   /// Whether to enable error message debugging. Defaults to `false`.
//   bool enableError = false,
// }) {
//   late final logger = Logger(
//     printer: PrettyPrinter(
//       lineLength: 250,
//       printTime: true,
//       methodCount: 0,
//       noBoxingByDefault: true,
//     ),
//   );

//   if (enableInfo) {
//     echox.on<String>('info', (info) {
//       logger.d(info);
//     });
//   }

//   if (enableStatus) {
//     echox.on<StatusEmitter>('status', (status) {
//       logger.w(status);
//     });
//   }

//   if (enableError) {
//     echox.on<Mishap>('error', (mishap) {
//       if (mishap is WebSocketMishap) {
//         logger.t(mishap, error: mishap.error);
//       } else {
//         logger.e(mishap);
//       }
//     });
//   }
// }
