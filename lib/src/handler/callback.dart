part of 'handler.dart';

/// A speciliazed [Handler] implementation for handling XMPP stanzas with
/// a sync callback.
///
/// Extends [Handler].
///
/// Allows you to define a handler with a sync callback function that gets
/// executed when the handler matches a stanza based on the provided matcher.
///
/// ### Example:
/// ```dart
/// final handler = CallbackHandler('idOfStanza', (stanza) {
///   log(stanza);
///   /// ...do something with matched stanza.
/// });
/// ```
///
/// For more information refer to [Handler].
class CallbackHandler extends Handler {
  /// Creates an instance of [CallbackHandler] with the specified parameters.
  CallbackHandler(super.name, this.callback, {required super.matcher});

  /// The sync callback function to be executed when the handler matches a
  /// stanza.
  void Function(StanzaBase stanza) callback;

  @override
  void run(StanzaBase stanza) => callback.call(stanza);
}

/// A speciliazed [Handler] implementation for handling XMPP stanzas with
/// a async callback.
///
/// Extends [Handler].
///
/// Allows you to define a handler with a async callback function that gets
/// executed when the handler matches a stanza based on the provided matcher.
///
/// ### Example:
/// ```dart
/// final handler = FutureCallbackHandler('idOfStanza', (stanza) {
///   log(stanza);
///   /// ...do something with matched stanza.
/// });
/// ```
///
/// For more information refer to [Handler].
class FutureCallbackHandler extends Handler {
  FutureCallbackHandler(super.name, this.callback, {required super.matcher});

  final Future<void> Function(StanzaBase stanza) callback;

  @override
  Future<void> run(StanzaBase payload) => callback(payload);
}
