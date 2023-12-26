import 'dart:async';

import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/exception.dart';
import 'package:echox/src/handler/callback.dart';
import 'package:echox/src/handler/handler.dart';
import 'package:echox/src/stanza/error.dart';
import 'package:echox/src/stanza/root.dart';
import 'package:echox/src/stream/base.dart';
import 'package:echox/src/stream/matcher/base.dart';
import 'package:echox/src/stream/matcher/id.dart';

class IQ extends RootStanza {
  IQ({super.transport, bool generateID = true})
      : super(
          name: 'iq',
          namespace: Echotils.getNamespace('CLIENT'),
          interfaces: {'type', 'to', 'from', 'id', 'query'},
          types: {'get', 'result', 'set', 'error'},
          pluginAttribute: 'iq',
        ) {
    if (generateID) {
      if (!receive && this['id'] == '') {
        if (transport != null) {
          this['id'] = Echotils.getUniqueId();
        } else {
          this['id'] = '0';
        }
      }
    }
  }

  String? _handlerID;

  Future<void> sendIQ<T>({
    FutureOr<T> Function(StanzaBase stanza)? callback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 2000,
  }) async {
    BaseMatcher? matcher;
    final completer = Completer<StanzaBase>();
    Handler? handler;

    if (transport!.sessionBind) {
      matcher = MatchIDSender(
        CriteriaType(
          transport!.boundJID,
          to,
          this['id'] as String,
        ),
      );
    } else {
      matcher = MatcherID(this['id']);
    }

    Future<void> successCallback(StanzaBase stanza) async {
      final type = stanza['type'];
      final error = StanzaError().copy(stanza.element!.getElement('error'));

      if (type == 'result') {
        if (!completer.isCompleted) {
          completer.complete(stanza);
        }
      } else if (type == 'error') {
        if (!completer.isCompleted) {
          completer.completeError(StanzaException.iq(error));
        }
      } else {
        if (callback is Future) {
          handler = FutureCallbackHandler(
            _handlerID!,
            successCallback,
            matcher: matcher!,
          );
        } else {
          handler =
              CallbackHandler(_handlerID!, successCallback, matcher: matcher!);
        }

        transport!.registerHandler(handler!);
      }

      if (callback != null) callback.call(stanza);
    }

    if (<String>{'get', 'set'}.contains(this['type'] as String)) {
      _handlerID = this['id'] as String;
      if (callback is Future) {
        handler = FutureCallbackHandler(
          _handlerID!,
          successCallback,
          matcher: matcher,
        );
      } else {
        handler =
            CallbackHandler(_handlerID!, successCallback, matcher: matcher);
      }

      transport!.registerHandler(handler!);
    }
    send();
  }
}
