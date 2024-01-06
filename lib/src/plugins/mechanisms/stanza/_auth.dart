part of '../feature.dart';

class _Auth extends StanzaBase {
  _Auth({super.transport})
      : super(
          name: 'auth',
          namespace: WhixpUtils.getNamespace('SASL'),
          interfaces: {'mechanism', 'value'},
          pluginAttribute: 'auth',
          getters: <Symbol, dynamic Function(dynamic args, XMLBase base)>{
            const Symbol('value'): (args, base) =>
                WhixpUtils.arrayBufferToBase64(
                  Uint8List.fromList(base.element!.innerText.codeUnits),
                ),
          },
          setters: <Symbol,
              void Function(dynamic value, dynamic args, XMLBase base)>{
            const Symbol('value'): (values, args, base) =>
                base.element!.innerText = WhixpUtils.unicode(values),
          },
          deleters: <Symbol, dynamic Function(dynamic args, XMLBase base)>{
            const Symbol('value'): (args, base) => base.element!.innerText = '',
          },
        );
}
