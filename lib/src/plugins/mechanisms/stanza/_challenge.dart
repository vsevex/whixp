part of '../feature.dart';

class _Challenge extends StanzaBase {
  _Challenge()
      : super(
          name: 'challenge',
          namespace: WhixpUtils.getNamespace('SASL'),
          interfaces: {'value'},
          pluginAttribute: 'challenge',
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
