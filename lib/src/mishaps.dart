import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/error/error.dart';

/// An exception representing WebSocket-related mishaps.
///
/// The [WebSocketMishap] class is an extension of the [Mishap] class and is used
/// to represent exceptions that occur in WebSocket communication. It provides
/// various factory constructors for different types of WebSocket mishaps.
class WebSocketMishap extends Mishap {
  /// Creates a WebSocketMishap with specific error and trace information.
  ///
  /// - [condition]: A description of the WebSocket mishap.
  /// - [text]: Additional information or context about the mishap.
  /// - [error]: The error associated with the mishap.
  /// - [trace]: Additional trace or context information.
  WebSocketMishap({
    required super.condition,
    super.text,
    this.error,
    this.trace,
  });

  /// The error information associated with the mishap.
  final dynamic error;

  /// The trace or additional context related to the mishap.
  final dynamic trace;

  /// Represents an unexpected WebSocket error.
  factory WebSocketMishap.unknown({
    String? text,
    dynamic error,
    dynamic trace,
  }) =>
      WebSocketMishap(
        condition: 'Unexpected WebSocket error occured',
        text: text,
        error: error,
        trace: trace,
      );

  /// Represents unexpected WebSocket closure.
  factory WebSocketMishap.unexpected({int? code, String? reason}) =>
      WebSocketMishap(
        condition: 'WebSocket closed unexpectedly',
        text: 'code: $code, reason: $reason',
      );

  /// Represents incorrect WebSocket URL.
  factory WebSocketMishap.incorrectURL(String service) =>
      WebSocketMishap(condition: 'No service was found under $service');

  /// Represents a WebSocket stream error.
  factory WebSocketMishap.streamError(String condition) =>
      WebSocketMishap(condition: condition);
}

/// An exception representing resource binding mishaps.
///
/// The [ResourceBindingMishap] class is an extension of the [Mishap] class and
/// is used to represent exceptions that occur during resource binding in an XMPP
/// session. It indicates a failure in resource binding.
class ResourceBindingMishap extends Mishap {
  ResourceBindingMishap() : super(condition: 'Resource binding failed');
}

/// An exception representing session establishment mishaps.
///
/// The [EstablishSessionMishap] class is an extension of the [Mishap] class and
/// is used to represent exceptions that occur when attempting to establish an
/// XMPP session but encountering errors related to session negotiation.
class EstablishSessionMishap extends Mishap {
  EstablishSessionMishap()
      : super(
          condition:
              'establishSession method was called but apparently ${Echotils.getNamespace('SESSION')} was not advertised by the server',
        );
}

/// An exception representing session creation mishaps.
///
/// The [SessionResultMishap] class is an extension of the [Mishap] class and
/// is used to represent exceptions that occur during the creation of an XMPP
/// session.
class SessionResultMishap extends Mishap {
  SessionResultMishap() : super(condition: 'Sesion creation failed');
}
