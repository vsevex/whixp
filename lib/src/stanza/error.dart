import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// Represents an XMPP stanza error.
///
/// Extends [XMLBase] and implements [Exception] interface.
///
/// This class is designed to handle XMPP stanza errors, specifically related
/// to client communication.
///
/// ### Example:
/// ```xml
/// <error type="cancel" code="404">
///   <item-not-found xmlns="urn:ietf:params:xml:ns:xmpp-stanzas" />
///   <text xmlns="urn:ietf:params:xml:ns:xmpp-stanzas">
///     Some error text.
///   </text>
/// </error>
/// ```
class StanzaError extends XMLBase implements Exception {
  /// Creates a new instance of [StanzaError] with optional parameters.
  ///
  /// [conditionNamespace] represents the XML namespace for conditions.
  StanzaError({
    super.getters,
    super.setters,
    super.deleters,
    String? conditionNamespace,
    super.element,
    super.parent,
  }) : super(
          name: 'error',
          namespace: WhixpUtils.getNamespace('CLIENT'),
          pluginAttribute: 'error',
          interfaces: {
            'code',
            'condition',
            'text',
            'type',
            'gone',
            'redirect',
            'by',
          },
          subInterfaces: {'text'},
        ) {
    _conditionNamespace =
        conditionNamespace ?? WhixpUtils.getNamespace('STANZAS');

    if (parent != null) {
      parent!['type'] = 'error';
    }

    addGetters(
      <Symbol, dynamic Function(dynamic args, XMLBase base)>{
        const Symbol('condition'): (args, base) => condition,

        /// Retrieves the contents of the <text> element.
        const Symbol('text'): (args, base) => base.getSubText('text'),
        const Symbol('gone'): (args, base) => base.getSubText('gone'),
      },
    );

    addSetters(
      <Symbol, void Function(dynamic value, dynamic args, XMLBase base)>{
        const Symbol('condition'): (value, args, base) {
          if (_conditions.contains(value as String)) {
            base.delete('condition');
            base.element!.children.add(WhixpUtils.xmlElement(value));
          }
        },
      },
    );

    addDeleters(
      <Symbol, dynamic Function(dynamic args, XMLBase base)>{
        /// Removes the condition element.
        const Symbol('condition'): (args, base) {
          final elements = <xml.XmlElement>[];
          for (final child in base.element!.childElements) {
            if (child.getAttribute('xmlns') == _conditionNamespace) {
              final condition = child.localName;
              if (_conditions.contains(condition)) {
                elements.add(child);
              }
            }
          }

          for (final element in elements) {
            base.element!.children.remove(element);
          }
        },
      },
    );
  }

  /// The namespace for the condition element.
  late final String _conditionNamespace;

  @override
  bool setup([xml.XmlElement? element]) {
    final setup = super.setup(element);
    if (setup) {
      this['type'] = 'cancel';
      this['condition'] = 'feature-not-implemented';
    }
    if (parent != null) {
      parent!['type'] = 'error';
    }
    return setup;
  }

  /// Returns the condition element's name.
  String get condition {
    for (final child in element!.childElements) {
      if (child.getAttribute('xmlns') == _conditionNamespace) {
        final condition = child.localName;
        if (_conditions.contains(condition)) {
          return condition;
        }
      }
    }
    return '';
  }

  @override
  StanzaError copy({
    xml.XmlElement? element,
    XMLBase? parent,
    bool receive = false,
  }) =>
      StanzaError(
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
        conditionNamespace: _conditionNamespace,
      );
}

/// Represents an XMPP stream error.
///
/// This class is designed to handle stream errors.
///
/// ### Example:
/// ```xml
/// <stream:error>
///   <not-well-formed xmlns="urn:ietf:params:xml:ns:xmpp-streams" />
///   <text xmlns="urn:ietf:params:xml:ns:xmpp-streams">
///     XML was not well-formed.
///   </text>
/// </stream:error>
/// ```
class StreamError extends StanzaBase implements Exception {
  /// XMPP stanzas of type `error` should inclue an __<error>__ stanza that
  /// describes the nature of the error and how it should be handled.
  ///
  /// The __stream:error__ stanza is used to provide more information for
  /// error that occur with underlying XML stream itself, and not a particular
  /// stanza.
  ///
  /// [conditionNamespace] represents the XML namespace for conditions.
  StreamError({
    super.getters,
    super.setters,
    super.deleters,
    super.element,
    super.parent,
    String? conditionNamespace,
  }) : super(
          name: 'error',
          namespace: WhixpUtils.getNamespace('JABBER_STREAM'),
          pluginAttribute: 'error',
          interfaces: {'condition', 'text', 'see_other_host'},
        ) {
    _conditionNamespace =
        conditionNamespace ?? WhixpUtils.getNamespace('STREAM');

    addGetters(
      <Symbol, dynamic Function(dynamic args, XMLBase base)>{
        const Symbol('see_other_host'): (args, base) {
          final namespace = _conditionNamespace;

          return base.getSubText('{$namespace}see-other-host');
        },
      },
    );

    addSetters(
      <Symbol, dynamic Function(dynamic value, dynamic args, XMLBase base)>{
        const Symbol('see_other_host'): (value, args, base) {
          if (value is String && value.isNotEmpty) {
            base.delete('condition');

            final namespace = _conditionNamespace;

            return base.getSubText('{$namespace}see-other-host');
          }
        },
      },
    );

    addDeleters(
      <Symbol, dynamic Function(dynamic args, XMLBase base)>{
        const Symbol('see_other_host'): (args, base) {
          final namespace = _conditionNamespace;

          return base.getSubText('{$namespace}see-other-host');
        },
      },
    );
  }

  /// The namespace for the condition element.
  late final String _conditionNamespace;

  @override
  StreamError copy({
    xml.XmlElement? element,
    XMLBase? parent,
    bool receive = false,
  }) =>
      StreamError(
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
        conditionNamespace: _conditionNamespace,
      );
}

const _conditions = {
  'bad-request',
  'conflict',
  'feature-not-implemented',
  'forbidden',
  'gone',
  'internal-server-error',
  'item-not-found',
  'jid-malformed',
  'not-acceptable',
  'not-allowed',
  'not-authorized',
  'payment-required',
  'recipient-unavailable',
  'redirect',
  'registration-required',
  'remote-server-not-found',
  'remote-server-timeout',
  'resource-constraint',
  'service-unavailable',
  'subscription-required',
  'undefined-condition',
  'unexpected-request',
};
