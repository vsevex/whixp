import 'package:echo/src/sasl.dart';

class SASLSHA1 extends SASL {
  SASLSHA1({
    super.mechanism = 'SCRAM-SHA-1',
    super.isClientFirst = true,
    super.priority = 80,
  });

  
}
