import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/stream/base.dart';

class StanzaError extends XMLBase implements Exception {
  StanzaError({String? conditionNamespace})
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
              return condition;
            }
          }
          return '';
        },
        const Symbol('text'): (args, base) => base.getSubText('text'),
        const Symbol('gone'): (args, base) => base.getSubText('gone'),
      },
    );
  }

  final conditions = {
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

  late final String _conditionNamespace;
}
