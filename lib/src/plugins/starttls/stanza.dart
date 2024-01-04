part of '../../whixp.dart';

class _StartTLS extends StanzaBase {
  _StartTLS()
      : super(
          name: 'starttls',
          namespace: Echotils.getNamespace('STARTTLS'),
          interfaces: {'required'},
          pluginAttribute: 'starttls',
          getters: <Symbol, dynamic Function(dynamic args, XMLBase base)>{
            const Symbol('required'): (args, base) => true,
          },
        );
}

class _Proceed extends StanzaBase {
  _Proceed()
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

class _Failure extends StanzaBase {
  _Failure()
      : super(
          name: 'failure',
          namespace: Echotils.getNamespace('STARTTLS'),
          interfaces: const {},
        );
}
