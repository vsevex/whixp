import 'dart:async';

import 'package:synchronized/extension.dart';

import 'package:whixp/src/exception.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/stanza/node.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/transport.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// IQ stanzas, or info/query stanzas, are XMPP's method of requesting and
/// modifying information, similar to HTTP's GET and POST methods.
///
/// Each __iq__ stanza must have an 'id' value which associates the stanza
/// with the response stanza. XMPP entities must always be given a response
/// IQ stanza with a type of 'result' after sending a stanza 'get' or 'set'.
///
/// Must use cases for IQ stanzas will involve adding a query element whose
/// namespace indicates the type of information desired. However, some custom
/// XMPP applications use IQ stanzas as a carrier stanza for an
/// application-specific protocol instead.
///
/// ### Example:
/// ```xml
/// <iq to="vsevex@localhost" type="get" id="412415323632">
///   <query xmlns="http://jabber.org/protocol/disco#items" />
/// </iq>
///
/// <iq type='set' id='bind_1'>
///   <bind xmlns='urn:ietf:params:xml:ns:xmpp-bind'/>
/// </iq>
/// ```
///
/// For more information on "id" and "type" please refer to [XML stanzas](https://xmpp.org/rfcs/rfc3920.html#stanzas)
class IQ extends Stanza with Attributes {
  static const String _name = 'iq';

  /// Constructs an IQ stanza.
  IQ({bool generateID = false}) {
    if (generateID) id = WhixpUtils.generateUniqueID();
    _handlerID = WhixpUtils.generateUniqueID('handler');
  }

  /// `Error` stanza associated with this IQ stanza, if any.
  ErrorStanza? error;

  /// Payload of the IQ stanza.
  Stanza? payload;

  /// Any other XML node associated with this IQ stanza.
  Node? any;

  String? _handlerID;

  /// Constructs an IQ stanza from a string representation.
  ///
  /// Throws [WhixpInternalException] if the input XML is invalid.
  factory IQ.fromString(String stanza) {
    try {
      final root = xml.XmlDocument.parse(stanza).rootElement;

      return IQ.fromXML(root);
    } catch (_) {
      throw WhixpInternalException.invalidXML();
    }
  }

  /// Constructs an IQ stanza from an XML element node.
  ///
  /// Throws [WhixpInternalException] if the provided XML node is invalid.
  factory IQ.fromXML(xml.XmlElement node) {
    if (node.localName != _name) {
      throw WhixpInternalException.invalidNode(node.localName, _name);
    }

    final iq = IQ();
    iq.loadAttributes(node);

    for (final child in node.children.whereType<xml.XmlElement>()) {
      switch (child.localName) {
        case 'error':
          iq.error = ErrorStanza.fromXML(child);
        default:
          try {
            final tag = WhixpUtils.generateNamespacedElement(child);

            iq.payload = Stanza.payloadFromXML(tag, child);
          } on WhixpException catch (exception) {
            iq.any = Node.fromXML(child);
            Log.instance.warning(exception.message);
          }
      }
    }

    return iq;
  }

  /// Converts the IQ stanza to its XML representation.
  @override
  xml.XmlElement toXML() {
    final dictionary = attributeHash;
    final builder = WhixpUtils.makeGenerator();

    builder.element(_name, attributes: dictionary);
    final root = builder.buildDocument().rootElement;

    if (payload != null) root.children.add(payload!.toXML().copy());
    if (error != null) root.children.add(error!.toXML().copy());
    if (any != null) root.children.add(any!.toXML().copy());

    return root;
  }

  /// Sends an IQ stanza over the XML stream.
  ///
  /// A callback handler can be provided that will be executed when the IQ
  /// stanza's result reply is received.
  ///
  /// Returns a [FutureOr] which result will be set to the result IQ if it is
  /// of type 'get' or 'set' (when it is received), or a [Future] with the
  /// result set to null if it has another type.
  ///
  /// You can set the return of the callback return type you have provided or
  /// just avoid this.
  FutureOr<IQ> send<T>(
    Transport transport, {
    /// Sync or async callback function which accepts the incoming "result"
    /// iq stanza.
    FutureOr<T> Function(IQ iq)? callback,

    /// Callback to be triggered when there is a failure occured.
    ///
    /// It is handy way of handling the failure, 'cause the [Completer] can not
    /// handle the uncaught exceptions.
    FutureOr<void> Function(ErrorStanza error)? failureCallback,

    /// Whenever there is a timeout, this callback method will be called.
    FutureOr<void> Function()? timeoutCallback,

    /// The length of time (in seconds) to wait for a response before the
    /// [timeoutCallback] is called, instead of the sync callback. Defaults to
    /// `10` seconds.
    int timeout = 5,
  }) {
    final completer = Completer<IQ?>();
    final errorCompleter = Completer<IQ?>();
    final resultCompleter = Completer<IQ>();

    Handler? handler;

    Future<void> successCallback(IQ iq) async {
      final type = iq.type;

      if (type == 'result') {
        if (!completer.isCompleted) {
          completer.complete(iq);
          resultCompleter.complete(iq);
          errorCompleter.complete(null);
        }
      } else if (type == 'error') {
        if (!completer.isCompleted && !errorCompleter.isCompleted) {
          try {
            completer.complete(null);
            errorCompleter.complete(iq);
            resultCompleter.complete(iq);
          } catch (error) {
            Log.instance.error(error.toString());
          }
        }
      } else {
        handler = Handler(
          _handlerID!,
          (stanza) => successCallback(stanza as IQ),
        )..id(id!);

        transport.registerHandler(handler!);
      }

      transport.cancelSchedule(_handlerID!);

      /// Run provided callback if there is any completed IQ stanza.
      if (callback != null) {
        final result = await completer.future;
        if (result != null) {
          await callback.call(result);
        }
      }

      /// Run provided failure callback if there is any completed error stanza.
      if (failureCallback != null) {
        final result = await errorCompleter.future;
        if (result != null && result.error != null) {
          await failureCallback.call(result.error!);
        }
      }
    }

    void callbackTimeout() {
      runZonedGuarded(
        () {
          if (!resultCompleter.isCompleted) {
            throw StanzaException.timeout(this, timeoutSeconds: timeout);
          }
        },
        (error, trace) {
          transport.removeHandler(_handlerID!);
          if (timeoutCallback != null) {
            timeoutCallback.call();
          }
        },
      );
    }

    if (<String>{'get', 'set'}.contains(type)) {
      handler = Handler(
        _handlerID!,
        (iq) => successCallback(iq as IQ),
      )..id(id!);

      transport
        ..registerHandler(handler!)
        ..schedule(handler!.name, callbackTimeout, seconds: timeout);
    }
    transport.send(this);

    // Set up timeout handling
    Future.delayed(Duration(seconds: timeout), () {
      if (!resultCompleter.isCompleted) {
        transport.removeHandler(_handlerID!);
        transport.cancelSchedule(_handlerID!);
        if (timeoutCallback != null) {
          timeoutCallback.call();
        }
        if (!resultCompleter.isCompleted) {
          resultCompleter.completeError(
            StanzaException.timeout(this, timeoutSeconds: timeout),
          );
        }
      }
    });

    return synchronized(() => resultCompleter.future);
  }

  /// Sets an error for this IQ stanza.
  void makeError(ErrorStanza error) {
    type = 'error';
    this.error = error;
  }

  /// Returns the name of the IQ stanza.
  @override
  String get name => _name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IQ &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          id == other.id &&
          payload == other.payload &&
          error == other.error &&
          any == other.any;

  @override
  int get hashCode =>
      type.hashCode ^
      id.hashCode ^
      payload.hashCode ^
      error.hashCode ^
      any.hashCode;
}
