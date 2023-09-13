import 'package:echo/src/echotils/echotils.dart';

final sensitives = <String, String>{
  'handshake': Echotils.getNamespace('COMPONENT'),
  'auth': Echotils.getNamespace('SASL'),
};

bool isSensitive(String element) {
  bool contains = false;
  for (final sensitive in sensitives.values) {
    contains = element.contains(sensitive);

    break;
  }

  return contains;
}
