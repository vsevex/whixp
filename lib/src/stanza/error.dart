import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/stream/base.dart';

class StanzaError extends XMLBase implements Exception {
  StanzaError({String? conditionNamespace, super.includeNamespace = false})
      : super(
          name: 'error',
          namespace: Echotils.getNamespace('CLIENT'),
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
        conditionNamespace ?? Echotils.getNamespace('STANZAS');

    if (parent != null) {
      parent!['type'] = 'error';
    }

    this['type'] = 'cancel';
    this['condition'] = 'feature-not-implemented';

    addGetters(
      <Symbol, dynamic Function(dynamic args, XMLBase base)>{
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
        const Symbol('text'): (args, base) => base.getSubText('text'),
        const Symbol('gone'): (args, base) => base.getSubText('gone'),
      },
    );
  }

  late final String _conditionNamespace;
}

class StreamError extends StanzaBase implements Exception {
  StreamError({String? conditionNamespace, super.includeNamespace = false})
      : super(
          name: 'error',
          namespace: Echotils.getNamespace('JABBER_STREAM'),
          pluginAttribute: 'error',
          interfaces: {'condition', 'text', 'see_other_host'},
        ) {
    _conditionNamespace = conditionNamespace ?? Echotils.getNamespace('STREAM');

    addGetters(
      <Symbol, dynamic Function(dynamic args, XMLBase base)>{
        const Symbol('see_other_host'): (args, base) {
          final namespace = _conditionNamespace;

          return base.getSubText(
            "//*[local-name()='see-other-host' and namespace-uri()='$namespace']",
          );
        },
      },
    );

    addSetters(
      <Symbol, dynamic Function(dynamic value, dynamic args, XMLBase base)>{
        const Symbol('see_other_host'): (value, args, base) {
          if (value is String && value.isNotEmpty) {
            base.delete('condition');

            final namespace = _conditionNamespace;
            base.setSubText(
              "//*[local-name()='see-other-host' and namespace-uri()='$namespace']",
            );
          }
        },
      },
    );

    addDeleters(
      <Symbol, dynamic Function(dynamic args, XMLBase base)>{
        const Symbol('see_other_host'): (args, base) {
          final namespace = _conditionNamespace;

          return base.deleteSub(
            "//*[local-name()='see-other-host' and namespace-uri()='$namespace']",
          );
        },
      },
    );
  }

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
