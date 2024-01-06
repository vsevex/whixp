part of '../feature.dart';

class _Response extends StanzaBase {
  _Response({super.transport})
      : super(
          name: 'response',
          namespace: WhixpUtils.getNamespace('SASL'),
          interfaces: {'value'},
          pluginAttribute: 'response',
          getters: <Symbol, dynamic Function(dynamic args, XMLBase base)>{
            const Symbol('value'): (args, base) =>
                WhixpUtils.atob(base.element!.innerText),
          },
          setters: <Symbol,
              void Function(dynamic value, dynamic args, XMLBase base)>{
            const Symbol('value'): (value, args, base) {
              if ((value as String).isNotEmpty) {
                base.element!.innerText = WhixpUtils.btoa(value);
              } else {
                base.element!.innerText = '=';
              }
            },
          },
          deleters: <Symbol, dynamic Function(dynamic args, XMLBase base)>{
            const Symbol('value'): (args, base) => base.element!.innerText = '',
          },
        );
}
