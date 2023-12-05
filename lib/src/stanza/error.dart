import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/stream/base.dart';

class StanzaError extends StanzaBase implements Exception {
  StanzaError()
      : super(
          namespace: Echotils.getNamespace('JABBER_STREAM'),
          interfaces: {'condition', 'text', 'see_other_host'},
        );

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

  final conditionNamespace = Echotils.getNamespace('STREAM');

  
}
