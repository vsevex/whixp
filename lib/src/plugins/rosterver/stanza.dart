part of 'rosterver.dart';

class RosterVersioning extends XMLBase {
  RosterVersioning()
      : super(
          name: 'ver',
          namespace: WhixpUtils.getNamespace('VER'),
          interfaces: const <String>{},
          pluginAttribute: 'rosterver',
        );
}
