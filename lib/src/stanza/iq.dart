import 'dart:async';

import 'package:synchronized/extension.dart';
import 'package:whixp/src/exception.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/bind/bind.dart';
import 'package:whixp/src/plugins/plugins.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/root.dart';
import 'package:whixp/src/stanza/roster.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/stream/matcher/matcher.dart';
import 'package:whixp/src/transport.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// IQ stanzas, or info/query stanzas, are XMPP's method of requesting and
/// modifying information, similar to HTTP's GET and POST methods.
///
/// Each __<iq>__ stanza must have an 'id' value which associates the stanza
/// with the response stanza. XMPP entities must always be given a response
/// IQ stanza with a type of 'result' after sending a stanza 'get' or 'set'.
///
/// Must use cases for IQ stanzas will involve adding a <query> element whose
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
class IQ extends RootStanza {
  /// All parameters are extended from [RootStanza]. For more information please
  /// take a look at [RootStanza].
  IQ({
    bool generateID = true,
    super.stanzaType,
    super.stanzaTo,
    super.stanzaFrom,
    super.stanzaID,
    super.transport,
    super.subInterfaces,
    super.languageInterfaces,
    super.includeNamespace = false,
    super.getters,
    super.setters,
    super.deleters,
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.pluginMultiAttribute,
    super.pluginIterables,
    super.overrides,
    super.isExtension,
    super.boolInterfaces,
    super.receive,
    super.element,
    super.parent,
  }) : super(
          name: 'iq',
          namespace: WhixpUtils.getNamespace('CLIENT'),
          interfaces: {'type', 'to', 'from', 'id', 'query'},
          types: {'get', 'result', 'set', 'error'},
          pluginAttribute: 'iq',
        ) {
    _generateID = generateID;
    if (_generateID) {
      if (!receive && (this['id'] == '' || this['id'] == null)) {
        if (transport != null) {
          this['id'] = WhixpUtils.getUniqueId();
        } else {
          this['id'] = '0';
        }
      }
    }

    addSetters(
      <Symbol, void Function(dynamic value, dynamic args, XMLBase base)>{
        const Symbol('query'): (value, args, base) {
          xml.XmlElement? query = base.element!.getElement(value as String);
          if (query == null && value.isNotEmpty) {
            final plugin = base
                .pluginTagMapping['<${base.name} xmlns="${base.namespace}"/>'];
            if (plugin != null) {
              base.enable(plugin.pluginAttribute);
            } else {
              base.clear();
              query = WhixpUtils.xmlElement('query', namespace: value);
              base.element!.children.add(query);
            }
          }
        },
      },
    );

    addGetters(
      <Symbol, String? Function(dynamic args, XMLBase base)>{
        const Symbol('query'): (args, base) {
          for (final child in base.element!.childElements) {
            if (child.qualifiedName.endsWith('query')) {
              final namespace = child.getAttribute('xmlns');
              return namespace;
            }
          }
          return '';
        },
      },
    );

    addDeleters(
      <Symbol, void Function(dynamic args, XMLBase base)>{
        const Symbol('query'): (args, base) {
          final elements = <xml.XmlElement>[];
          for (final child in base.element!.childElements) {
            if (child.qualifiedName.endsWith('query')) {
              elements.add(child);
            }
          }

          for (final element in elements) {
            base.element!.children.removeWhere((el) => el == element);
          }
        },
      },
    );

    /// Register all required stanzas beforehand, so we won't need to declare
    /// them one by one whenever there is a need to specific stanza.
    ///
    /// If you have not used the specified stanza, then you have to enable the
    /// stanza through the usage of `pluginAttribute` parameter.
    registerPlugin(StanzaError());
    registerPlugin(BindStanza());
    registerPlugin(Roster());
    registerPlugin(Form());
    registerPlugin(PingStanza());
    registerPlugin(DiscoveryItems());
    registerPlugin(DiscoveryInformation());
    registerPlugin(RSMStanza());
    registerPlugin(PubSubStanza());
    registerPlugin(PubSubOwnerStanza());
    registerPlugin(Register());
    registerPlugin(VCardTempStanza());
    registerPlugin(Command());
  }

  /// The id of the attached [Handler].
  String? _handlerID;

  /// Indicates that whether generate ID or not.
  late final bool _generateID;

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
  FutureOr<IQ> sendIQ<T>({
    /// Sync or async callback function which accepts the incoming "result"
    /// iq stanza.
    FutureOr<T> Function(IQ iq)? callback,

    /// Callback to be triggered when there is a failure occured.
    ///
    /// It is handy way of handling the failure, 'cause the [Completer] can not
    /// handle the uncaught exceptions.
    FutureOr<void> Function(StanzaError error)? failureCallback,

    /// Whenever there is a timeout, this callback method will be called.
    FutureOr<void> Function()? timeoutCallback,

    /// The length of time (in seconds) to wait for a response before the
    /// [timeoutCallback] is called, instead of the sync callback. Defaults to
    /// `10` seconds.
    int timeout = 10,
  }) async {
    final completer = Completer<IQ?>();
    final errorCompleter = Completer<IQ?>();
    final resultCompleter = Completer<IQ>();

    Handler? handler;
    BaseMatcher? matcher;

    if (transport!.sessionBind) {
      final toJID = to ?? JabberID(transport!.boundJID.domain);

      matcher = MatchIDSender(
        IDMatcherCriteria(
          transport!.boundJID,
          toJID,
          this['id'] as String,
        ),
      );
    } else {
      matcher = MatcherID(this['id'] as String);
    }

    Future<void> successCallback(StanzaBase iq) async {
      IQ stanza;
      if (iq is! IQ) {
        stanza = IQ(element: iq.element);
      } else {
        stanza = iq;
      }
      final type = stanza['type'];

      if (type == 'result') {
        if (!completer.isCompleted) {
          completer.complete(stanza);
          resultCompleter.complete(stanza);
          errorCompleter.complete(null);
        }
      } else if (type == 'error') {
        if (!completer.isCompleted && !errorCompleter.isCompleted) {
          try {
            completer.complete(null);
            errorCompleter.complete(stanza);
            resultCompleter.complete(stanza);

            throw StanzaException.iq(stanza);
          } catch (error) {
            Log.instance.error(error.toString());
          }
        }
      } else {
        handler = FutureCallbackHandler(
          _handlerID!,
          (stanza) => Future.microtask(() => successCallback(stanza))
              .timeout(Duration(seconds: timeout)),
          matcher: matcher!,
        );

        transport?.registerHandler(handler!);
      }

      transport?.cancelSchedule(_handlerID!);

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
        if (result != null) {
          await failureCallback.call(result['error'] as StanzaError);
        }
      }
    }

    void callbackTimeout() {
      runZonedGuarded(
        () {
          if (!resultCompleter.isCompleted) {
            throw StanzaException.timeout(this);
          }
        },
        (error, trace) {
          transport?.removeHandler(_handlerID!);
          if (timeoutCallback != null) {
            timeoutCallback.call();
          }
        },
      );
    }

    if (<String>{'get', 'set'}.contains(this['type'] as String)) {
      _handlerID = this['id'] as String;

      handler = FutureCallbackHandler(
        _handlerID!,
        (iq) => Future.microtask(() => successCallback(iq))
            .timeout(Duration(seconds: timeout)),
        matcher: matcher,
      );

      transport!
        ..schedule(_handlerID!, callbackTimeout, seconds: timeout)
        ..registerHandler(handler!);
    }
    send();

    return synchronized(() => resultCompleter.future);
  }

  /// Send a 'feature-not-implemented' error stanza if the stanza is not
  /// handled.
  @override
  void unhandled([Transport? transport]) {
    if ({'get', 'set'}.contains(this['type'])) {
      final iq = replyIQ();
      iq.transport ??= transport ?? this.transport;
      iq
        ..registerPlugin(StanzaError())
        ..enable('error');
      final error = iq['error'] as XMLBase;
      error['condition'] = 'feature-not-implemented';
      error['text'] = 'No handlers registered';
      iq.sendIQ();
    }
  }

  @override
  IQ error() {
    super.error();
    return this;
  }

  /// Overrides [reply] method, instead copies [IQ] with the overrided [copy]
  /// method.
  IQ replyIQ({bool clear = true}) {
    final iq = super.reply<IQ>(copiedStanza: copy(), clear: clear);
    iq['type'] = 'result';
    return iq;
  }

  @override
  IQ copy({xml.XmlElement? element, XMLBase? parent, bool receive = false}) =>
      IQ(
        generateID: _generateID,
        pluginMultiAttribute: pluginMultiAttribute,
        overrides: overrides,
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        subInterfaces: subInterfaces,
        boolInterfaces: boolInterfaces,
        languageInterfaces: languageInterfaces,
        pluginIterables: pluginIterables,
        isExtension: isExtension,
        includeNamespace: includeNamespace,
        getters: getters,
        setters: setters,
        deleters: deleters,
        receive: receive,
        element: element,
        parent: parent,
      );
}
