part of 'echox.dart';

/// Private helper class for managing stanza handlers.
///
/// Encapsulates a user provided callback function to be executed when matching
/// stanzas are received by the connection.
///
/// Handlers can be either one-off or persistant depending on their return
/// value. Returning true will cause a Handler to remain active, and returning
/// false will remove the Handler.
///
/// Users will not use Handlers directly, instead they will use
/// `EchoX.addHandler()` or `EchoX.deleteHandler()` method.
class Handler {
  Handler(
    /// Required for executing when `run` is triggered.
    this.handler, {
    /// The namespace of the stanzas to match. If null, all namespaces will be
    /// considered a match.
    this.namespace,

    /// The name of the stanzas to match. If null, all names will be considered
    /// a match.
    this.name,

    /// The type of the stanzas to match. If null, all types will be considered
    /// a match.
    this.type,

    /// The id of the stanzas to match. If null, all ids will be considered a
    /// match.
    this.id,

    /// The source of the stanzas to match. If null, all sources will be
    /// considered a match.
    String? from,

    /// Additional options for the handler.
    ///
    Map<String, bool>? options,
  }) : options = options ??
            {
              /// If set to true, it indicates that the from attribute should
              /// be matched with the bare JID (Jabber ID) instead of the full
              /// `JID`.
              ///
              /// Default is `false`.
              'matchBareFromJid': false,

              /// If set to true, it indicates that the namespace should be
              /// compared without considering any fragment after the '#'
              /// character.
              ///
              /// Default is false.
              'ignoreNamespaceFragment': false,
            } {
    if (this.options!.containsKey('matchBare')) {
      this.options!['matchBareFromJid'] = this.options!['matchBareFromJid']!;
      this.options!.remove('matchBare');
    }
    if (this.options!.containsKey('matchBareFromJid')) {
      this.from =
          from != null ? JabberID.fromString(from).bare.toString() : null;
    } else {
      this.from = from;
    }

    /// Whether the handler is a user handler or a system handler.
    user = true;
  }

  /// The source of the stanzas to match.
  String? from;

  /// The `namespace` of the stanzas to match, If null, all namespaces will be
  /// considered a match.
  final String? namespace;

  /// The `name` of the stanzas to match.
  final String? name;

  /// The `type` of the stanzas to match. Can be used as [String] or [List].
  final dynamic type;

  /// The `id` of the stanzas to match.
  final String? id;

  /// Additional `options` for the handler.
  final Map<String, bool>? options;

  /// The [Function] executor needs to be run when needed.
  final FutureOr<bool> Function(xml.XmlElement)? handler;

  /// Authentication flag for the handler.
  bool user = false;

  /// Retrieves the namespacce of an XML element.
  String? getNamespace(xml.XmlElement element) {
    /// Defaults to the attribute of `xlmns`.
    String? namespace = element.getAttribute('xmlns');

    /// If not null and the options contain dedicated param, then split `#` sign
    /// from `namespace`.
    if (namespace != null && options!['ignoreNamespaceFragment']!) {
      namespace = namespace.split('#')[0];
    }
    return namespace;
  }

  /// Checks if the namespace of an XML [element] matches the specified
  /// namespace.
  bool namespaceMatch(xml.XmlElement element) {
    /// Defaults to false.
    bool isNamespaceMatches = false;

    /// If null then return true that namespace matches.
    if (namespace == null) return true;
    Echotils.forEachChild(element, null, (node) {
      if (getNamespace(node) == namespace) {
        isNamespaceMatches = true;
      }
    });
    return isNamespaceMatches || getNamespace(element) == namespace;
  }

  /// Checks if an XML [element] matches the specified criteria.
  bool isMatch(xml.XmlElement element) {
    /// Default to the attribute under name of `from` on the passed `element`
    String? from = element.getAttribute('from');

    if (options!['matchBareFromJid']!) {
      from = JabberID.fromString(from!).bare.toString();
    }
    final elementType = element.getAttribute('type');
    if (namespaceMatch(element) &&
        (name == null || Echotils.isTagEqual(element, name!)) &&
        (type == null ||
            (type is List
                ? (type! as List).contains(elementType)
                : elementType == type)) &&
        (id == null || element.getAttribute('id') == id) &&
        (this.from == null || from == this.from)) {
      return true;
    }

    return false;
  }

  /// Runs the handler function on the specified XML [element].
  FutureOr<bool> run(xml.XmlElement element) => handler!.call(element);

  @override
  String toString() =>
      '{Handler: $handler (name: $name, id: $id, namespace: $namespace type: $type options: $options)}';
}

/// Private helper class for managing timed handlers.
///
/// Encapsulates a user provided callback that should be called after a certain
/// period of time or at regulra intervals. The return value of the callback
/// determines whether the [_TimedHandler] will continue to fire.
///
/// Users will not use this class objects directly, but instead
/// they will use this class's `addTimedHandler()` method and
/// `deleteTimedHandler()` method.
class _TimedHandler {
  _TimedHandler({
    required this.period,
    required this.handler,
  }) {
    /// Equal the last call time to now.
    lastCalled = DateTime.now();
  }

  /// The number of milliseconds to wait before the handler is called.
  final int period;

  /// The callback to run when the handler fires. This function should take no
  /// arguments.
  final bool Function() handler;

  /// Nullable param for indicating lastCalled time of the handler.
  DateTime? lastCalled;

  bool user = true;

  /// Run the callback for the [_TimedHandler].
  bool run() {
    /// Equals last called time to now.
    lastCalled = DateTime.now();

    /// Calls handler.
    return handler.call();
  }

  /// Reset the last called time for the [_TimedHandler].
  void reset() {
    /// Equals `lastCalled` variable to `DateTime.now()`.
    lastCalled = DateTime.now();
  }

  /// Get a string representation of the [_TimedHandler] object.
  @override
  String toString() => '''TimedHandler: $handler ($period)''';
}
