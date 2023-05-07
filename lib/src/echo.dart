import 'package:echo/src/builder.dart';
import 'package:echo/src/log.dart';
import 'package:echo/src/utils.dart';

import 'package:xml/xml.dart' as xml;

class Echo {
  Echo(this.name, {this.attributes}) {
    /// Initialize [EchoBuilder] after the creation of the [Echo].
    builder = EchoBuilder(name, attributes);
  }

  /// Creates an [Echo] with a <message/> element as the root.
  factory Echo.message({Map<String, String>? attributes}) =>
      Echo('message', attributes: attributes);

  /// Creates an [Echo] with an <iq/> element as the root.
  factory Echo.iq({Map<String, String>? attributes}) =>
      Echo('iq', attributes: attributes);

  /// Creates an [Echo] with a <presence/> element as the root.
  factory Echo.pres({Map<String, String>? attributes}) =>
      Echo('presence', attributes: attributes);

  /// `version` constant
  static const version = '0.0.1';

  /// [String] representation of the name of an XML element that is being
  /// constructed by the builder.
  final String name;

  /// [Map] representation of attribute key-value pairs for the XML element
  /// being constructed.
  Map<String, String>? attributes;

  /// Late initialization of [EchoBuilder] builder class.
  late final EchoBuilder builder;
}

void _handleError(dynamic e) {
  Log().fatal(e.toString());
}

class Handler {
  Handler({
    this.handler,
    this.namespace,
    this.name,
    this.type,
    this.id,
    String? from,
    Map<String, bool>? options,
  }) : options = options ??
            {
              'matchBareFromJid': false,
              'ignoreNamespaceFragment': false,
            } {
    if (options!.containsKey('matchBare')) {
      Log().warn(
        'The "matchBare" option is deprecated, use "matchBareFromJid" instead.',
      );
      this.options!['matchBareFromJid'] = options['matchBareFromJid']!;
      options.remove('matchBare');
    }
    if (options.containsKey('matchBareFromJid')) {
      this.from = from != null ? Utils().getBareJIDFromJID(from) : null;
    } else {
      this.from = from;
    }
  }

  String? from;
  final bool Function(xml.XmlElement element)? handler;
  final String? namespace;
  final String? name;
  final String? type;
  final String? id;
  final Map<String, bool>? options;

  String? getNamespace(xml.XmlElement element) {
    String? namespace = element.getAttribute('xlmns');
    if (namespace != null && options!['ignoreNamespaceFragment']!) {
      namespace = namespace.split('#')[0];
    }
    return namespace;
  }

  bool namespaceMatch(xml.XmlElement element) {
    bool isNamespaceMatches = false;
    if (namespace == null) return true;
    Utils.forEachChild(element, null, (node) {
      if (getNamespace(element) == namespace) {
        isNamespaceMatches = true;
      }
    });
    return isNamespaceMatches || getNamespace(element) == namespace;
  }

  bool isMatch(xml.XmlElement element) {
    String? from = element.getAttribute('from');
    if (options!['matchBareFromJid']!) {
      from = Utils().getBareJIDFromJID(from!);
    }
    final elementType = element.getAttribute('type');
    if (namespaceMatch(element) &&
        (name == null || Utils.isTagEqual(element, name!)) &&
        (type == null || type is List
            ? type!.contains(elementType!)
            : elementType == type) &&
        (id == null || element.getAttribute('id') == id) &&
        (from == null || from == this.from)) {
      return true;
    }
    return false;
  }

  bool? run(xml.XmlElement element) {
    bool? result;
    try {
      result = handler!.call(element);
    } catch (e) {
      _handleError(e);
    }
    return result;
  }

  @override
  String toString() => '{Handler: $handler ($name, $id, $namespace)}';
}

class _TimedHandler {
  _TimedHandler(
    this.period,
    this.handler, {
    DateTime? lastCalled,
    this.user = true,
  }) {
    this.lastCalled = lastCalled ?? DateTime.now();
  }

  final int period;
  final bool Function()? handler;
  final bool user;
  DateTime? lastCalled;

  bool run() {
    lastCalled = DateTime.now();
    return handler!.call();
  }

  void reset() => lastCalled = DateTime.now();

  @override
  String toString() => '{TimeHandler: $handler($period)}';
}
