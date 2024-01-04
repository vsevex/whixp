import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/stream/base.dart';

class RosterVersioning extends XMLBase {
  RosterVersioning()
      : super(
          name: 'ver',
          namespace: Echotils.getNamespace('VER'),
          interfaces: const <String>{},
          pluginAttribute: 'rosterver',
        );
}
