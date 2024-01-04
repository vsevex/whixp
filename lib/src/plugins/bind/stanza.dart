import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/stream/base.dart';

class BindStanza extends XMLBase {
  BindStanza({super.element})
      : super(
          name: 'bind',
          namespace: Echotils.getNamespace('BIND'),
          interfaces: {'resource', 'jid'},
          subInterfaces: {'resource', 'jid'},
          pluginAttribute: 'bind',
        );
}
