import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/jid/jid.dart';
import 'package:echox/src/stanza/root.dart';
import 'package:echox/src/stream/base.dart';

class Message extends RootStanza {
  Message({super.transport, super.includeNamespace = false})
      : super(
          name: 'message',
          namespace: Echotils.getNamespace('CLIENT'),
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
        this['id'] = Echotils.getUniqueId();
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
                  Echotils.xmlElement('thread', namespace: namespace);
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

  void chat() => this['type'] = 'chat';

  void normal() => this['type'] = 'normal';

  Message replyMessage({String? body, bool clear = true}) {
    final message = super.reply<Message>(copiedStanza: copy(), clear: clear);

    if (this['type'] == 'groupchat') {
      message['to'] = JabberID(message['to'] as String).bare;
    }

    message['thread'] = this['thread'];
    message['parent_thread'] = this['parent_thread'];

    message.delete('id');

    if (transport != null) {
      message['id'] = Echotils.getUniqueId();
    }

    if (body != null) {
      message['body'] = body;
    }

    return message;
  }

  String get mucRoom {
    if (this['type'] == 'groupchat') {
      return JabberID(this['from'] as String).bare;
    }
    return '';
  }

  String get mucNick {
    if (this['type'] == 'groupchat') {
      return JabberID(this['from'] as String).resource;
    }
    return '';
  }

  @override
  Message copy([dynamic element, XMLBase? parent, bool receive = false]) =>
      Message(transport: transport);

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
      final sub = Echotils.xmlElement('origin-id', namespace: 'urn:xmpp:sid:0');
      sub.setAttribute('id', value);
      return base.element!.children.add(sub);
    }
  }
}
