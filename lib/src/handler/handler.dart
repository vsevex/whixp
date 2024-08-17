import 'dart:async';

import 'package:whixp/src/handler/matcher.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/utils/utils.dart';

/// A handler for processing packets based on various matching criteria.
class Handler {
  /// Constructs a handler with a [name] and a [callback] function.
  Handler(this.name, this.callback);

  /// The name of the handler.
  final String name;

  /// The callback function to be executed when a packet matches the handler's
  /// criteria.
  final FutureOr<void> Function(Packet packet) callback;

  /// List of matchers added to the handler.
  final _matchers = <Matcher>[];

  /// Adds a matcher to the handler.
  void addMatcher(Matcher matcher) => _matchers.add(matcher);

  /// Matches the incoming packet against the registered matchers.
  ///
  /// If a match is found, the associated callback function is executed. Returns
  /// `true` if a match is found, otherwise `false`.
  bool match(Packet packet) {
    for (final matcher in _matchers) {
      if (matcher.match(packet)) {
        callback.call(packet);
        return true;
      }
    }

    return false;
  }

  /// Adds a matcher that matches packets with a specific [name].
  void packet(String name) => addMatcher(NameMatcher(name));

  /// Adds a matcher that contains both success and failure stanza name(s).
  void sf(Tuple2<String, String> sf) =>
      addMatcher(SuccessAndFailureMatcher(sf));

  /// Adds a matcher that matches packets with a specific IQ [id].
  void id(String id) => addMatcher(IQIDMatcher(id));

  void descendant(String descendants) =>
      addMatcher(DescendantMatcher(descendants));

  /// Adds a matcher that matches packets based on their stanza [types].
  void stanzaType(List<String> types) =>
      addMatcher(NamespaceTypeMatcher(types));

  /// Adds a matcher that matches IQ packets based on their [namespaces].
  void iqNamespaces(List<String> namespaces) => addMatcher(
        NamespaceIQMatcher(
          namespaces.map((namespace) => namespace.toLowerCase()).toList(),
        ),
      );
}
