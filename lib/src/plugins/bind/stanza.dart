part of 'bind.dart';

@internal
class BindStanza extends XMLBase {
  BindStanza({super.element})
      : super(
          name: 'bind',
          namespace: WhixpUtils.getNamespace('BIND'),
          interfaces: {'resource', 'jid'},
          subInterfaces: {'resource', 'jid'},
          pluginAttribute: 'bind',
        );
}
