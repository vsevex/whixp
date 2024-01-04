part of '../stream/base.dart';

class IQ extends RootStanza {
  IQ({
    super.stanzaType,
    super.stanzaTo,
    super.stanzaFrom,
    super.stanzaID,
    super.transport,
    bool generateID = true,
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
          namespace: Echotils.getNamespace('CLIENT'),
          interfaces: {'type', 'to', 'from', 'id', 'query'},
          types: {'get', 'result', 'set', 'error'},
          pluginAttribute: 'iq',
        ) {
    if (generateID) {
      if (!this.receive && (this['id'] == '' || this['id'] == null)) {
        if (transport != null) {
          this['id'] = Echotils.getUniqueId();
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
              query = Echotils.xmlElement('query', namespace: value);
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

  String? _handlerID;

  FutureOr<void> sendIQ<T>({
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
      iq.send();
    }
  }

  IQ replyIQ({bool clear = true}) {
    final iq = super.reply<IQ>(copiedStanza: copy(), clear: clear);
    iq['type'] = 'result';
    return iq;
  }

  @override
  IQ copy([xml.XmlElement? element, XMLBase? parent, bool receive = false]) =>
      IQ(
        subInterfaces: _subInterfaces,
        languageInterfaces: _languageInterfaces,
        getters: _getters,
        setters: _setters,
        deleters: _deleters,
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: _pluginAttributeMapping,
        pluginMultiAttribute: _pluginMultiAttribute,
        pluginIterables: _pluginIterables,
        overrides: _overrides,
        isExtension: _isExtension,
        setupOverride: setupOverride,
        boolInterfaces: _boolInterfaces,
        includeNamespace: _includeNamespace,
        receive: receive,
        element: element,
        parent: parent,
      );
}
