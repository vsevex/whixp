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
class Command extends XMLBase {
  /// Example:
  /// ```xml
  /// <iq type="set">
  ///   <command xmlns="http://jabber.org/protocol/commands"
  ///            node="run_foo"
  ///            action="execute" />
  /// </iq>
  /// ```
  Command({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.pluginIterables,
    super.getters,
    super.setters,
    super.deleters,
    super.element,
    super.parent,
  }) : super(
          name: 'command',
          namespace: 'http://jabber.org/protocol/commands',
          pluginAttribute: 'command',
          interfaces: <String>{
            'action',
            'sessionid',
            'node',
            'status',
            'actions',
            'notes',
          },
          includeNamespace: true,
        ) {
    addGetters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('action'): (args, base) => action,
      const Symbol('actions'): (args, base) => actions,
      const Symbol('notes'): (args, base) => notes,
    });

    addSetters(<Symbol,
        void Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('actions'): (value, args, base) =>
          setActions(value as List<String>),
      const Symbol('notes'): (value, args, base) =>
          setNotes(value as Map<String, String>),
    });

    addDeleters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('actions'): (args, base) => deleteActions(),
      const Symbol('notes'): (args, base) => deleteNotes(),
    });

    registerPlugin(Form(), iterable: true);
  }

  /// Returns the value of the `action` attribute.
  String get action {
    if (parent!['type'] == 'set') {
      return getAttribute('action', 'execute');
    }
    return getAttribute('action');
  }

  /// Assign the set of allowable next actions.
  void setActions(List<String> values) {
    delete('actions');
    if (values.isNotEmpty) {
      setSubText('{$namespace}actions', text: '', keep: true);
      final actions = element!.getElement('actions', namespace: namespace);
      for (final value in values) {
        if (_nextActions.contains(value)) {
          final action = WhixpUtils.xmlElement(value);
          element!.childElements
              .firstWhere((element) => element == actions)
              .children
              .add(action);
        }
      }
    }
  }

  /// Returns the [Iterable] of the allowable next actions.
  Iterable<String> get actions {
    final actions = <String>[];
    final actionElements = element!.getElement('actions', namespace: namespace);
    if (actionElements != null) {
      for (final action in _nextActions) {
        final actionElement =
            actionElements.getElement(action, namespace: namespace);
        if (actionElement != null) {
          actions.add(action);
        }
      }
    }
    return actions;
  }

  /// Remove all allowable next actions.
  void deleteActions() => deleteSub('{$namespace}actions');

  /// Returns a [Map] of note information.
  Map<String, String> get notes {
    final notes = <String, String>{};
    final xml = element!.findAllElements('note', namespace: namespace);
    for (final note in xml) {
      notes.addAll({note.getAttribute('type') ?? 'info': note.innerText});
    }
    return notes;
  }

  /// Adds multiple notes to the command result.
  ///
  /// [Map] representation the notes, with the key being of "info", "warning",
  /// or "error", and the value of [notes] being any human readable message.
  ///
  /// ### Example:
  /// ```dart
  /// final notes = {
  ///   'info': 'salam, blyat!',
  ///   'warning': 'do not go gentle into that good night',
  /// };
  /// ```
  void setNotes(Map<String, String> notes) {
    delete('notes');
    for (final note in notes.entries) {
      addNote(note.value, note.key);
    }
  }

  /// Removes all note associated with the command result.
  void deleteNotes() {
    final notes = element!.findAllElements('note', namespace: namespace);
    for (final note in notes) {
      element!.children.remove(note);
    }
  }

  /// Adds a single [note] annotation to the command.
  void addNote(String note, String type) {
    final xml = WhixpUtils.xmlElement('note');
    xml.setAttribute('type', type);
    xml.innerText = note;
    element!.children.add(xml);
  }

  final _nextActions = <String>{'prev', 'next', 'complete'};

  @override
  Command copy({xml.XmlElement? element, XMLBase? parent}) => Command(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        pluginIterables: pluginIterables,
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}
