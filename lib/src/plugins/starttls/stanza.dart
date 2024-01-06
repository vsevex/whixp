part of 'starttls.dart';

/// ```xml
/// <starttls xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>
/// ```
@internal
class StartTLS extends StanzaBase {
  StartTLS()
      : super(
          name: 'starttls',
          namespace: WhixpUtils.getNamespace('STARTTLS'),
          interfaces: {'required'},
          pluginAttribute: 'starttls',
          getters: <Symbol, dynamic Function(dynamic args, XMLBase base)>{
            const Symbol('required'): (args, base) => true,
          },
        );
}

/// ```xml
/// <proceed xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>
/// ```
@internal
class Proceed extends StanzaBase {
  Proceed()
      : super(
          name: 'proceed',
          namespace: WhixpUtils.getNamespace('STARTTLS'),
          interfaces: const {},
        );

  @override
  void exception(dynamic excp) => throw excp as Exception;
}

/// ```xml
/// <failure xmlns='urn:ietf:params:xml:ns:xmpp-tls'/>
/// ```
@internal
class Failure extends StanzaBase {
  Failure()
      : super(
          name: 'failure',
          namespace: WhixpUtils.getNamespace('STARTTLS'),
          interfaces: const {},
        );
}
