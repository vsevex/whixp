import 'package:whixp/src/exception.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/stanza/node.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// The [MessageType] enum defines various types of messages that can be
/// associated with a [Message] stanza. Each message type has a distinct
/// meaning and can be used to categorize different kinds of messages.
///
/// ### Example:
/// ```dart
/// final messageType = MessageType.chat;
/// ```
enum MessageType { chat, error, groupchat, headline, normal }

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
///   <body>hohoho!</body>
/// </message>
/// ```
class Message extends Stanza with Attributes {
  static const String _name = 'message';

  /// Constructs a message stanza.
  Message({
    this.subject,
    this.body,
    this.thread,
    this.nick,
  });

  /// The subject of the message.
  final String? subject;

  /// The body of the message.
  final String? body;

  /// The thread ID associated with the message.
  final String? thread;

  /// The nick associated with the message.
  final String? nick;

  /// Indicates whether the sender requests displayed marker or not. Always
  /// 'false' for sent messages.
  bool _isMarked = false;

  /// Error stanza associated with this message stanza, if any.
  ErrorStanza? _error;

  /// List of payloads associated with this message stanza.
  final _payloads = <Stanza>[];

  /// List of extension nodes associated with this message stanza.
  final extensions = <MessageExtension>[];

  /// Constructs a message stanza from a string representation.
  ///
  /// Throws [WhixpInternalException] if the input XML is invalid.
  factory Message.fromString(String stanza) {
    try {
      final doc = xml.XmlDocument.parse(stanza);
      final root = doc.rootElement;

      return Message.fromXML(root);
    } catch (_) {
      throw WhixpInternalException.invalidXML();
    }
  }

  /// Constructs a message stanza from an XML element node.
  ///
  /// Throws [WhixpInternalException] if the provided XML node is invalid.
  factory Message.fromXML(xml.XmlElement node) {
    String? subject;
    String? body;
    String? thread;
    String? nick;
    ErrorStanza? error;
    bool isMarked = false;
    final payloads = <Stanza>[];
    final extensions = <MessageExtension>[];

    for (final child in node.children.whereType<xml.XmlElement>()) {
      switch (child.localName) {
        case 'subject':
          subject = child.innerText;
        case 'body':
          body = child.innerText;
        case 'thread':
          thread = child.innerText;
        case 'nick':
          nick = child.innerText;
        case 'markable':
          isMarked = true;
        case 'error':
          error = ErrorStanza.fromXML(child);
        default:
          try {
            final tag = WhixpUtils.generateNamespacedElement(child);
            final stanza = Stanza.payloadFromXML(tag, child);

            payloads.add(stanza);
          } on WhixpException {
            if (child.localName.isNotEmpty && child.attributes.isNotEmpty) {
              final extension = MessageExtension(child.localName);
              for (final attribute in child.attributes) {
                extension.addAttribute(attribute.localName, attribute.value);
              }
              extensions.add(extension);
            }
          }
          break;
      }
    }
    final message = Message(
      subject: subject,
      body: body,
      thread: thread,
      nick: nick,
    )
      .._isMarked = isMarked
      .._error = error;
    message._payloads.addAll(payloads);
    message.extensions.addAll(extensions);
    message.loadAttributes(node);

    return message;
  }

  /// Converts the message stanza to its XML representation.
  @override
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();
    final attributes = attributeHash;

    builder.element(
      _name,
      attributes: attributes,
      nest: () {
        if (subject?.isNotEmpty ?? false) {
          builder.element('subject', nest: () => builder.text(subject!));
        }
        if (body?.isNotEmpty ?? false) {
          builder.element('body', nest: () => builder.text(body!));
        }
        if (nick?.isNotEmpty ?? false) {
          builder.element('nick', nest: () => builder.text(nick!));
        }
        if (thread?.isNotEmpty ?? false) {
          builder.element('thread', nest: () => builder.text(thread!));
        }
      },
    );

    final root = builder.buildDocument().rootElement;

    for (final payload in _payloads) {
      root.children.add(payload.toXML().copy());
    }

    for (final extension in extensions) {
      root.children.add(extension.toXML().copy());
    }

    return root;
  }

  /// Adds payload [Stanza] to the given [Message].
  void addPayload(Stanza payload) => _payloads.add(payload);

  /// Adds an extension to the given [Message].
  void addExtension(MessageExtension extension) => extensions.add(extension);

  /// Returns a list of payloads of a specific type associated with this message
  /// stanza.
  List<S> get<S extends Stanza>() => _payloads.whereType<S>().toList();

  /// Trys to get [MessageExtension] from message itself. If there is no
  /// extension under the given [name], then returns null.
  MessageExtension? getExtension(String name) {
    if (extensions.isEmpty) return null;
    final exts = extensions.where((ext) => ext.name == name);

    if (exts.isEmpty) return null;
    return exts.first;
  }

  /// Returns the name of the message stanza.
  @override
  String get name => _name;

  /// Indicates if the message is marked as "requires display information from
  /// receiver".
  bool get isMarked => _isMarked;

  /// Returns the error stanza associated with this message stanza, if any.
  ErrorStanza? get error => _error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Message &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          subject == other.subject &&
          body == other.body &&
          thread == other.thread &&
          _error == other._error &&
          _payloads == other._payloads &&
          extensions == other.extensions;

  @override
  int get hashCode =>
      subject.hashCode ^
      id.hashCode ^
      body.hashCode ^
      thread.hashCode ^
      _error.hashCode ^
      _payloads.hashCode ^
      extensions.hashCode;
}

/// An extension for the message that can be added beside of the message stanza.
class MessageExtension extends Node {
  MessageExtension(super.name);
}
