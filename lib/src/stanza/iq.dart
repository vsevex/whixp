import 'dart:async';

import 'package:whixp/src/exception.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/root.dart';
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
    super.setupOverride,
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
    if (generateID) {
      if (!this.receive && (this['id'] == '' || this['id'] == null)) {
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
  }

  /// The id of the attached [Handler].
  String? _handlerID;

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
  FutureOr<void> sendIQ<T>({
    /// Sync or async callback function which accepts the incoming "result"
    /// stanza.
    FutureOr<T> Function(StanzaBase stanza)? callback,

    /// Whenever there is a timeout, this callback method will be called.
    FutureOr<void> Function()? timeoutCallback,

    /// The length of time (in milliseconds) to wait for a response before the
    /// [timeoutCallback] is called, instead of the sync callback.
    int timeout = 2000,
  }) async {
    final completer = Completer<StanzaBase>();

    Handler? handler;
    BaseMatcher? matcher;

    if (transport!.sessionBind) {
      matcher = MatchIDSender(
        IDMatcherCriteria(
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

      if (type == 'result') {
        if (!completer.isCompleted) {
          completer.complete(stanza);
        }
      } else if (type == 'error') {
        stanza.registerPlugin(StanzaError());
        stanza.enable('error');
        if (!completer.isCompleted) {
          completer.completeError(StanzaException.iq(stanza));
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

  /// Send a 'feature-not-implemented' error stanza if the stanza is not
  /// handled.
  @override
  void unhandled([Transport? transport]) {
    if ({'get', 'set'}.contains(this['type'])) {
      if (this.transport == null) {
        this.transport = transport;
      }
      final iq = replyIQ();
      iq
        ..registerPlugin(StanzaError())
        ..enable('error');
      final error = iq['error'] as XMLBase;
      error['condition'] = 'feature-not-implemented';
      error['text'] = 'No handlers registered';
      iq.sendIQ();
    }
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
        setupOverride: setupOverride,
        receive: receive,
        element: element,
        parent: parent,
      );
}
