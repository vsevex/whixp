import 'package:echox/echox.dart';
import 'package:echox/src/stream/base.dart';

class StartTLS extends StanzaBase {
  StartTLS()
      : super(
          name: 'starttls',
          namespace: Echotils.getNamespace('STARTTLS'),
          interfaces: {'required'},
          pluginAttribute: 'starttls',
          getters: {const Symbol('required'): (args, base) => true},
        );
}

class Proceed extends StanzaBase {
  Proceed()
      : super(
          name: 'proceed',
          namespace: Echotils.getNamespace('STARTTLS'),
          interfaces: const {},
        );

  @override
  void exception(Exception excp) {
    print('error handling $name stanza');
  }
}

class Failure extends StanzaBase {
  Failure()
      : super(
          name: 'failure',
          namespace: Echotils.getNamespace('STARTTLS'),
          interfaces: const {},
        );
}
