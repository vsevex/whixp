import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/stanza/root.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// XMPP's <message> stanza are a "push" mechanism to send information to
/// other XMPP entities without requiring a response.
///
/// Chat clients will typically use [Message] stanzas that have a type of either
/// "chat" or "groupchat".
///
/// When handling a message event, be sure to check if the message is an error
/// response.
///
/// ### Example:
/// ```xml
/// <message to="vsevex@example.com" from="alyosha@example.com">
///   <body>salam!</body>
/// </message>
/// ```
///
/// For more information on "id" and "type" please refer to [XML stanzas](https://xmpp.org/rfcs/rfc3920.html#stanzas)
class Message extends RootStanza {
  /// [types] may be one of: normal, chat, headline, groupchat, or error.
  ///
  /// All parameters are extended from [RootStanza]. For more information please
  /// take a look at [RootStanza].
  Message({
    super.transport,
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
          name: 'message',
          namespace: WhixpUtils.getNamespace('CLIENT'),
          pluginAttribute: 'message',
          interfaces: {
            'type',
            'to',
            'from',
            'id',
            'body',
            'subject',
            'thread',
            'parent_thread',
            'mucroom',
            'mucnick',
          },
          subInterfaces: {'body', 'subject', 'thread'},
          languageInterfaces: {'body', 'subject', 'thread'},
          types: {'normal', 'chat', 'headline', 'error', 'groupchat'},
        ) {
    if (!receive && this['id'] == '') {
      if (transport != null) {
        this['id'] = WhixpUtils.getUniqueId();
      }
    }

    addSetters(
      <Symbol, void Function(dynamic value, dynamic args, XMLBase base)>{
        const Symbol('id'): (value, args, base) => _setIDs(value, base),
        const Symbol('origin-id'): (value, args, base) => _setIDs(value, base),
        const Symbol('parent_thread'): (value, args, base) {
          var element = base.element;
          if (element != null) {
            element = base.element!.getElement('thread', namespace: namespace);
          }
          if (value != null) {
            if (element == null) {
              final thread =
                  WhixpUtils.xmlElement('thread', namespace: namespace);
              base.element!.children.add(thread);
            }
          } else {
            if (element != null && element.getAttribute('parent') != null) {
              element.removeAttribute('parent');
            }
          }
        },
      },
    );

    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('type'): (args, base) => base.getAttribute('type', 'normal'),
      const Symbol('id'): (args, base) => base.getAttribute('id'),
      const Symbol('origin-id'): (args, base) {
        var element = base.element;
        if (element != null) {
          element = base.element!
              .getElement('origin-id', namespace: 'urn:xmpp:sid:0');
        }
        if (element != null) {
          return element.getAttribute('id') ?? '';
        }
        return '';
      },
      const Symbol('parent_thread'): (args, base) {
        final element = base.element;
        if (element != null) {
          final thread =
              base.element!.getElement('thread', namespace: namespace);
          if (thread != null) {
            return thread.getAttribute('parent') ?? '';
          }
        }
        return '';
      },
    });

    addDeleters(
      <Symbol, void Function(dynamic args, XMLBase base)>{
        const Symbol('origin-id'): (args, base) {
          var element = base.element;
          if (element != null) {
            element = base.element!
                .getElement('origin-id', namespace: 'urn:xmpp:sid:0');
          }
          if (element != null) {
            base.element!.children.remove(element);
          }
        },
        const Symbol('parent_thread'): (args, base) {
          var element = base.element;
          if (element != null) {
            element =
                base.element!.getElement('origin-id', namespace: namespace);
          }
          if (element != null && element.getAttribute('parent') != null) {
            element.removeAttribute('parent');
          }
        },
      },
    );
  }

  /// Set the message type to "chat".
  void chat() => this['type'] = 'chat';

  /// Set the message type to "normal".
  void normal() => this['type'] = 'normal';

  /// Overrider of [reply] method for [Message] stanza class. Can take optional
  /// [body] parameter which is assigned to the body of the [Message] stanza.
  ///
  /// Sets proper "to" attribute if the message is a from a MUC.
  Message replyMessage({String? body, bool clear = true}) {
    final message = super.reply<Message>(copiedStanza: copy(), clear: clear);

    if (this['type'] == 'groupchat') {
      message['to'] = JabberID(message['to'] as String).bare;
    }

    message['thread'] = this['thread'];
    message['parent_thread'] = this['parent_thread'];

    message.delete('id');

    if (transport != null) {
      message['id'] = WhixpUtils.getUniqueId();
    }

    if (body != null) {
      message['body'] = body;
    }

    return message;
  }

  /// Return the name of the MUC room where the message originated.
  String get mucRoom {
    if (this['type'] == 'groupchat') {
      return JabberID(this['from'] as String).bare;
    }
    return '';
  }

  /// Return the nickname of the MUC user that sent the message.
  String get mucNick {
    if (this['type'] == 'groupchat') {
      return JabberID(this['from'] as String).resource;
    }
    return '';
  }

  @override
  Message copy({
    xml.XmlElement? element,
    XMLBase? parent,
    bool receive = false,
  }) =>
      Message(
        pluginMultiAttribute: pluginMultiAttribute,
        overrides: overrides,
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        boolInterfaces: boolInterfaces,
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

  void _setIDs(dynamic value, XMLBase base) {
    if (value == null || value == '') {
      return;
    }

    base.element!.setAttribute('id', value as String);

    final sub =
        base.element!.getElement('origin-id', namespace: 'urn:xmpp:sid:0');
    if (sub != null) {
      sub.setAttribute('id', value);
    } else {
      final sub =
          WhixpUtils.xmlElement('origin-id', namespace: 'urn:xmpp:sid:0');
      sub.setAttribute('id', value);
      return base.element!.children.add(sub);
    }
  }
}
