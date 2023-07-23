part of 'echo.dart';

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
/// `Echo.addHandler()` or `Echo.deleteHandler()` method.
class Handler extends Event<Either<xml.XmlElement, EchoException>> {
  Handler(
    /// Required for executing when `run` is triggered.
    this.handler, {
    /// The namespace of the stanzas to match. If null, all namespaces will be
    /// considered a match.
    this.namespace,

    /// The name of the stanzas to match. If null, all names will be considered
    /// a match.
    this.stanzaName,

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
    this.completer,
  })  : options = options ??
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
            },
        super(name: id ?? 'generated-handler') {
    if (this.options!.containsKey('matchBare')) {
      Log().trigger(
        LogType.warn,
        'The "matchBare" option is deprecated, use "matchBareFromJid" instead',
      );
      this.options!['matchBareFromJid'] = this.options!['matchBareFromJid']!;
      this.options!.remove('matchBare');
    }
    if (this.options!.containsKey('matchBareFromJid')) {
      this.from = from != null ? Echotils().getBareJIDFromJID(from) : null;
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
  final String? stanzaName;

  /// The `type` of the stanzas to match. Can be used as [String] or [List].
  final dynamic type;

  /// The `id` of the stanzas to match.
  final String? id;

  /// Additional `options` for the handler.
  final Map<String, bool>? options;

  /// The [Function] executor needs to be run when needed.
  final FutureOr<bool> Function(xml.XmlElement)? handler;

  late final Completer<Either<xml.XmlElement, EchoException>>? completer;

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

  /// Checks if the namespace of an XML element matches the specified namespace.
  ///
  /// * @param element The XML element to check.
  /// * @return True if the element's namespace matches the specified namespace.
  /// Otherwise `false`.
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

  /// Checks if an XML element matches the specified criteria.
  ///
  /// * @param element The XML element to check.
  /// * @return True if the element matches the specified criteria. Otherwise
  /// `false`.
  bool isMatch(xml.XmlElement element) {
    /// Default to the attribute under name of `from` on the passed `element`
    String? from = element.getAttribute('from');

    if (options!['matchBareFromJid']!) {
      from = Echotils().getBareJIDFromJID(from!);
    }
    final elementType = element.getAttribute('type');
    if (namespaceMatch(element) &&
        (stanzaName == null || Echotils.isTagEqual(element, stanzaName!)) &&
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

  /// Runs the handler function on the specified XML element.
  ///
  /// * @param element The XML element to process.
  /// * @return The result of the handler function, if available.
  /// Otherwise returns null.
  FutureOr<bool>? run(xml.XmlElement element) async {
    bool? result;

    /// If handler is not null, then execute the passed function.
    if (handler != null) {
      result = await handler!.call(element);
    }

    if (element.getAttribute('type') == 'error') {
      /// Initialize null [EchoException].
      EchoException? exception;

      /// Iterate the `condition` over switch case and match the extension
      /// during this.
      switch (_mapErrors(element)!.value1) {
        case 'bad-request':
          exception = EchoExceptionMapper.badRequest();
        case 'not-authorized':
          exception = EchoExceptionMapper.notAuthorized();
        case 'forbidden':
          exception = EchoExceptionMapper.forbidden();
        case 'not-allowed':
          exception = EchoExceptionMapper.notAllowed();
        case 'registration-required':
          exception = EchoExceptionMapper.registrationRequired();
        case 'remote-server-timeout':
          exception = EchoExceptionMapper.requestTimedOut();
        case 'conflict':
          exception = EchoExceptionMapper.conflict();
        case 'internal-server-error':
          exception = EchoExceptionMapper.internalServerError();
        case 'service-unavailable':
          exception = EchoExceptionMapper.serviceUnavailable();
        case 'disconnected':
          exception = EchoExceptionMapper.disconnected();
      }

      /// If there is not [EchoException] catched, then fire [Right] side of
      /// the [Event].
      if (exception != null) {
        /// Check if there is any inner error text associated with the server
        /// message, if yes, then continue to print that code to the output.
        if (element.getElement('error')!.getElement('text') != null &&
            element
                .getElement('error')!
                .getElement('text')!
                .innerText
                .isNotEmpty) {
          exception = exception.copyWith(
            message: element.getElement('error')!.getElement('text')!.innerText,
          );
        }
        if (completer != null) {
          completer!.complete.call(Right(exception));
        } else {
          fire(Right(exception));
        }
      }
    } else {
      if (completer != null) {
        completer!.complete.call(Left(element));
      } else {
        /// If there is not any [EchoException] catched and `completer` is not
        /// null, then fire [Left] side of the [Event].
        fire(Left(element));
      }
    }

    return result ?? true;
  }

  @override
  String toString() =>
      '{Handler: $handler (name: $stanzaName, id: $id, namespace: $namespace type: $type options: $options)}';
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

  bool user = true;

  /// Nullable param for indicating lastCalled time of the handler.
  DateTime? lastCalled;

  /// Run the callback for the [_TimedHandler].
  ///
  /// * @return `true` if the [_TimedHandler] should be called again, otherwise
  /// false.
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
