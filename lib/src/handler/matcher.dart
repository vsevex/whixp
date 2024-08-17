import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/message.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/stanza/presence.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;
import 'package:xml/xpath.dart';

/// An abstract class representing a matcher for packet filtering.
abstract class Matcher {
  /// Constructs a matcher with an optional [name].
  const Matcher(this.name);

  /// The name of the matcher.
  final String? name;

  /// Checks if the given [packet] matches the criteria defined by the matcher.
  bool match(Packet packet);
}

class IQIDMatcher extends Matcher {
  // Constructor that initializes the id and calls the superclass constructor
  IQIDMatcher(this.id) : super('id-matcher');

  // Instance variable to store the ID
  final String id;

  // Override the match method to implement custom matching logic
  @override
  bool match(Packet packet) {
    // Check if the packet is not an IQ packet, return false if it's not
    if (packet is! IQ) return false;
    // Check if the packet's ID matches the provided ID
    return packet.id == id;
  }
}

/// A matcher that matches packets based on their name.
class NameMatcher extends Matcher {
  /// Constructs a name matcher with the specified [name].
  NameMatcher(super.name);

  @override
  bool match(Packet packet) => name == packet.name;
}

class SuccessAndFailureMatcher extends Matcher {
  SuccessAndFailureMatcher(this.sf) : super('success-failure-matcher');

  final Tuple2<String, String> sf;

  @override
  bool match(Packet packet) =>
      packet.name == sf.firstValue || packet.name == sf.secondValue;
}

/// Type of [Matcher] designed to match packets based on their XML structure.
///
/// It extends the functionality of the [Matcher] class by providing a mechanism
/// to check if a packet's XML representation has a specific depth of nested
/// elements.
class DescendantMatcher extends Matcher {
  /// Creates an instance of DescendantMatcher with the specified nesting
  /// [names].
  DescendantMatcher(this.names) : super('descendant-matcher');

  /// Names of nesting (e.g. "message/event/items") to check for in the packet's
  /// XML structure.
  final String names;

  @override
  bool match(Packet packet) {
    final descendants = names.split('/');
    late int level = 1;

    if (packet.name != descendants.first) return false;

    try {
      for (final name in descendants.sublist(1)) {
        final element = xml.XmlDocument.parse(
          packet.toXML().xpath('/*' * (level + 1)).first.toXmlString(),
        ).rootElement;

        if (element.localName == name) {
          level++;
        }
      }

      if (level == descendants.length) return true;

      return false;
    } catch (_) {
      return false;
    }
  }
}

/// A matcher that matches packets based on their stanza type and namespace.
class NamespaceTypeMatcher extends Matcher {
  /// Constructs a namespace-type matcher with the specified [types].
  NamespaceTypeMatcher(this.types) : super(null);

  /// The list of stanza types to match.
  final List<String> types;

  @override
  bool match(Packet packet) {
    String? type;

    switch (packet.runtimeType) {
      case IQ _:
        type = (packet as IQ).type;
      case Presence _:
        type = (packet as Presence).type;
      case Message _:
        type = (packet as Message).type;
        type = (type?.isEmpty ?? true) ? 'normal' : type;
      default:
        return false;
    }

    if (type?.isEmpty ?? true) return false;
    return types.contains(type);
  }
}

/// A matcher that matches IQ packets based on their namespaces.
class NamespaceIQMatcher extends Matcher {
  /// Constructs a namespace IQ matcher with the specified [types].
  NamespaceIQMatcher(this.types) : super(null);

  /// The list of IQ packet namespaces to match.
  final List<String> types;

  @override
  bool match(Packet packet) {
    if (packet is! IQStanza) return false;
    return types.contains(packet.namespace);
  }
}
