import 'package:whixp/src/_static.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/stanza/mixins.dart';
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
  static void route(Packet packet, Transport transport) {
    final matchedName = _matchedHandlerName(packet);
    if (matchedName != null) {
      Log.instance
          .debug('[STANZA_RX] Router -> matched handler "$matchedName"');
      return;
    }

    Log.instance.debug('[STANZA_RX] Router -> no handler for ${packet.name}');
    if (packet is IQ && [iqTypeGet, iqTypeSet].contains(packet.type)) {
      Log.instance.debug(
          '[STANZA_RX] Router -> sending feature-not-implemented for IQ');
      return _notImplemented(packet, transport);
    }
  }

  /// Returns the name of the first matching handler, or null if none.
  static String? _matchedHandlerName(Packet packet) {
    for (final handler in _handlers) {
      if (handler.match(packet)) return handler.name;
    }
    return null;
  }

  /// Adds a [handler] to the list of registered handlers.
  static void addHandler(Handler handler) {
    final found = _handlers.indexWhere((hndlr) => hndlr.name == handler.name);
    if (found == -1) return _handlers.add(handler);
    _handlers[found] = handler;
  }

  /// Removes a [handler] from the registered handlers list.
  static void removeHandler(String name) =>
      _handlers.removeWhere((handler) => handler.name == name);

  /// Clears all registerd route handlers.
  static void clearHandlers() => _handlers.clear();

  /// Sends a feature-not-implemented error response for the unhandled [iq].
  static void _notImplemented(IQ iq, Transport transport) {
    final error = ErrorStanza();
    error.code = 501;
    error.type = errorCancel;
    error.reason = 'feature-not-implemented';
    iq.makeError(error);
    transport.send(iq);
  }
}
