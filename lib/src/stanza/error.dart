import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/utils/utils.dart';

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
  ///
  /// [super.includeNamespace] is an optional parameter from the super class
  /// that indicates to whether include the namespace or not. Deafults to
  /// `false`.
  StanzaError({String? conditionNamespace, super.includeNamespace = false})
      : super(
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

    /// Sets a default type for this stanza.
    this['type'] = 'cancel';

    /// Sets a default condition for this stanza.
    this['condition'] = 'feature-not-implemented';

    addGetters(
      <Symbol, dynamic Function(dynamic args, XMLBase base)>{
        /// Return the condition element's name.
        const Symbol('condition'): (args, base) {
          for (final child in base.element!.childElements) {
            if (child.getAttribute('xmlns') == _conditionNamespace) {
              final condition = child.localName;
              if (_conditions.contains(condition)) {
                return condition;
              }
            }
          }
          return '';
        },

        /// Retrieve the contents of the <text> element.
        const Symbol('text'): (args, base) => base.getSubText('text'),
        const Symbol('gone'): (args, base) => base.getSubText('gone'),
      },
    );
  }

  /// The namespace for the condition element.
  late final String _conditionNamespace;
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
  ///
  /// [super.includeNamespace] is an optional parameter from the super class
  /// that indicates to whether include the namespace or not. Deafults to
  /// `false`.
  StreamError({String? conditionNamespace, super.includeNamespace = false})
      : super(
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

          return base.getSubText('<see-other-host xmlns="$namespace"/>');
        },
      },
    );

    addSetters(
      <Symbol, dynamic Function(dynamic value, dynamic args, XMLBase base)>{
        const Symbol('see_other_host'): (value, args, base) {
          if (value is String && value.isNotEmpty) {
            base.delete('condition');

            final namespace = _conditionNamespace;

            return base.getSubText('<see-other-host xmlns="$namespace"/>');
          }
        },
      },
    );

    addDeleters(
      <Symbol, dynamic Function(dynamic args, XMLBase base)>{
        const Symbol('see_other_host'): (args, base) {
          final namespace = _conditionNamespace;

          return base.deleteSub('<see-other-host xmlns="$namespace"/>');
        },
      },
    );
  }

  /// The namespace for the condition element.
  late final String _conditionNamespace;
}

const _conditions = {
  'bad-format',
  'bad-namespace-prefix',
  'conflict',
  'connection-timeout',
  'host-gone',
  'host-unknown',
  'improper-addressing',
  'internal-server-error',
  'invalid-from',
  'invalid-namespace',
  'invalid-xml',
  'not-authorized',
  'not-well-formed',
  'policy-violation',
  'remote-connection-failed',
  'reset',
  'resource-constraint',
  'restricted-xml',
  'see-other-host',
  'system-shutdown',
  'undefined-condition',
  'unsupported-encoding',
  'unsupported-feature',
  'unsupported-stanza-type',
  'unsupported-version',
};
