part of 'command.dart';

/// XMPP's Adhoc Commands provides a generic workflow mechanism for interacting
/// with applications. The result is similar to menu selections and multi-step
/// dialogs in normal desktop applications. Clients do not need to know in
/// advance what commands are provided by any particular application or agent.
///
/// While adhoc commands provide similar functionality to Jabber-RPC, adhoc
/// commands are used primarily for human interaction.
///
/// see <http://xmpp.org/extensions/xep-0050.html>
class Command extends IQStanza {
  /// Creates an instance of `Command`.
  const Command(
    this.node, {
    this.action,
    this.sessionID,
    this.status,
    this.payloads,
    this.resultActions,
  });

  /// The node identifier of the command.
  final String? node;

  /// The action to be performed by the command.
  final String? action;

  /// The list of action(s) from the `result` stanza.
  final List<String>? resultActions;

  /// The session ID of the command.
  final String? sessionID;

  /// The status of the command.
  final String? status;

  /// The Command form payload.
  final List<Stanza>? payloads;

  /// Creates a `Command` instance from an XML element.
  ///
  /// - [node]: An XML element representing an Adhoc Command.
  factory Command.fromXML(xml.XmlElement node) {
    String? action;
    String? status;
    String? sessionID;
    final actions = <String>[];
    final payloads = <Stanza>[];

    // Iterate over the child elements of the node to extract vCard information
    for (final attribute in node.attributes) {
      switch (attribute.localName) {
        case 'status':
          status = attribute.innerText;
        case 'sessionid':
          sessionID = attribute.innerText;
      }
    }

    for (final child in node.children.whereType<xml.XmlElement>()) {
      switch (child.localName) {
        case 'actions':
          for (final child in child.children.whereType<xml.XmlElement>()) {
            actions.add(child.localName);
          }
      }
      payloads.add(
        Stanza.payloadFromXML(
          WhixpUtils.generateNamespacedElement(child),
          child,
        ),
      );
    }

    return Command(
      node.getAttribute('node'),
      action: action,
      status: status,
      sessionID: sessionID,
      payloads: payloads,
      resultActions: actions,
    );
  }

  /// Converts the `VCard4` instance to an XML element.
  @override
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();
    final attributes = <String, String>{};

    if (sessionID?.isNotEmpty ?? false) {
      attributes['sessionid'] = sessionID!;
    }
    if (node?.isNotEmpty ?? false) {
      attributes['node'] = node!;
    }
    if (action?.isNotEmpty ?? false) {
      attributes['action'] = action!;
    }

    builder.element(
      name,
      attributes: <String, String>{'xmlns': namespace}..addAll(attributes),
      nest: () {
        if (status?.isNotEmpty ?? false) {
          builder.element('status', nest: () => builder.text(status!));
        }
      },
    );

    final element = builder.buildDocument().rootElement;
    if (payloads?.isNotEmpty ?? false) {
      for (final payload in payloads!) {
        element.children.add(payload.toXML().copy());
      }
    }

    return element;
  }

  /// The name of the XML element representing the vCard.
  @override
  String get name => 'command';

  /// The XML namespace for the vCard 4.0.
  @override
  String get namespace => 'http://jabber.org/protocol/commands';

  /// A tag used to identify the vCard element.
  @override
  String get tag => adhocCommandTag;
}
