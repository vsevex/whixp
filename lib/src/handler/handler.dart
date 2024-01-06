import 'dart:async';

import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/stream/matcher/base.dart';
import 'package:whixp/src/transport.dart';

part 'callback.dart';

/// An abstract class representing a generic handler for processing XMPP
/// stanzas.
///
/// Handlers are responsible for processing stanzas based on a defined
/// matching criteria.
///
/// ### Example:
/// ```dart
/// class CustomHandler extends Handler{
///   final matcher = Matcher();
///   final handler = CustomHandler('customIQHandler', matcher: matcher);
/// }
///
/// void main() {
///   final stanzaFromServer = StanzaBase();
///
///   handler.run(stanzaFromServer);
/// }
/// ```
abstract class Handler {
  /// Creates an instance of the [Handler] with the specified parameters.
  Handler(this.name, {required this.matcher, this.transport});

  /// The name of the [Handler].
  final String name;

  /// The matcher used to determine whether the handler should process the
  /// given stanza.
  final BaseMatcher matcher;

  /// This can be initialized through [Transport] class later, so cannot be
  /// marked as final.
  ///
  /// This instance will help us to use the instance of [Transport] to send
  /// over stanzas if mandatory.
  Transport? transport;

  /// Determines whether the given [StanzaBase] object matches the criteria
  /// defined by the handler's matcher.
  bool match(StanzaBase stanza) => matcher.match(stanza);

  /// Executes the handler's logic to process the given [StanzaBase] payload.
  FutureOr<void> run(StanzaBase payload);
}
