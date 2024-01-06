part of 'preapproval.dart';

class PreApproval extends XMLBase {
  PreApproval()
      : super(
          name: 'sub',
          namespace: WhixpUtils.getNamespace('PREAPPROVAL'),
          interfaces: const <String>{},
          pluginAttribute: 'preapproval',
        );
}
