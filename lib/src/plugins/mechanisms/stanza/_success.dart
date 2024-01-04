part of '../feature.dart';

class _Success extends StanzaBase {
  _Success()
      : super(
          name: 'success',
          namespace: Echotils.getNamespace('SASL'),
          interfaces: {'value'},
          pluginAttribute: 'success',
          getters: <Symbol, dynamic Function(dynamic args, XMLBase base)>{
            const Symbol('value'): (args, base) =>
                Echotils.atob(base.element!.innerText),
          },
          setters: <Symbol,
              void Function(dynamic value, dynamic args, XMLBase base)>{
            const Symbol('value'): (value, args, base) {
              if ((value as String).isNotEmpty) {
                base.element!.innerText = Echotils.btoa(value);
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
