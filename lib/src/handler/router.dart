import 'package:whixp/src/_static.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/transport.dart';
import 'package:whixp/whixp.dart';

/// A router for handling incoming packets by matching them with registered
/// handlers.
class Router {
  const Router();

  /// List of registered handlers for routing packets.
  static final _handlers = <Handler>[];

  /// Routes the incoming [packet] by matching it with registered handlers.
  ///
  /// If a matching handler is found, the packet is processed accordingly.
  ///
  /// If no matching handler is found, it checks if the packet is an IQ stanza
  /// with 'get' or 'set' type, and responds with a `feature-not-implemented`
  /// error if necessary.
  static void route(Packet packet) {
    if (_match(packet)) {
      return;
    }

    if (packet is IQ && [iqTypeGet, iqTypeSet].contains(packet.type)) {
      return _notImplemented(packet);
    }
  }

  /// Adds a [handler] to the list of registered handlers.
  static void addHandler(Handler handler) => _handlers.add(handler);

  /// Removes a [handler] from the registered handlers list.
  static void removeHandler(String name) =>
      _handlers.removeWhere((handler) => handler.name == name);

  /// Clears all registerd route handlers.
  static void clearHandlers() => _handlers.clear();

  /// Matches the incoming [packet] with registered handlers.
  ///
  /// Returns `true` if a matching handler is found, otherwise `false`.
  static bool _match(Packet packet) {
    for (final handler in _handlers) {
      final match = handler.match(packet);
      if (match) return true;
    }
    return false;
  }

  /// Sends a feature-not-implemented error response for the unhandled [iq].
  static void _notImplemented(IQ iq) {
    final error = ErrorStanza();
    error.code = 501;
    error.type = errorCancel;
    error.reason = 'feature-not-implemented';
    iq.makeError(error);
    Transport.instance().send(iq);
  }
}
