import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/stream/base.dart';

class PreApproval extends XMLBase {
  PreApproval()
      : super(
          name: 'sub',
          namespace: Echotils.getNamespace('PREAPPROVAL'),
          interfaces: const <String>{},
          pluginAttribute: 'preapproval',
        );
}
