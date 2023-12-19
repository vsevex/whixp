part of '../feature.dart';

class _Failure extends StanzaBase {
  _Failure()
      : super(
          name: 'failure',
          namespace: Echotils.getNamespace('SASL'),
          interfaces: {'condition', 'text'},
          pluginAttribute: 'failure',
          subInterfaces: {'text'},
        );
}
