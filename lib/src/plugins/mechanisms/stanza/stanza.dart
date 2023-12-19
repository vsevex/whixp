import 'package:dartz/dartz.dart';

import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/stream/base.dart';

import 'package:xml/xml.dart' as xml;

class Mechanisms extends XMLBase {
  Mechanisms()
      : super(
          name: 'mechanisms',
          namespace: Echotils.getNamespace('SASL'),
          interfaces: {'mechanisms', 'required'},
          pluginAttribute: 'mechanisms',
          isExtension: true,
          getters: <Symbol, dynamic Function(dynamic args, XMLBase base)>{
            const Symbol('required'): (_, __) => true,
            const Symbol('mechanisms'): (args, base) {
              final results = <String>[];
              final mechs =
                  base.parent!.element!.findAllElements('mechanism').toList();
              if (mechs.isNotEmpty) {
                for (final mech in mechs) {
                  results.add(mech.innerText);
                }
              }
              return results;
            },
          },
          setters: <Symbol,
              void Function(dynamic value, dynamic args, XMLBase base)>{
            const Symbol('mechanisms'): (values, args, base) {
              base.delete('mechanisms');
              for (final value in values as List<String>) {
                final mech = xml.XmlElement(xml.XmlName('mechanism'));
                mech.innerText = value;
                base.parent!.add(Tuple2(mech, null));
              }
            },
          },
          deleters: <Symbol, dynamic Function(dynamic args, XMLBase base)>{
            const Symbol('mechanisms'): (args, base) {
              final mechs =
                  base.parent!.element!.findAllElements('mechanism').toList();
              if (mechs.isNotEmpty) {
                for (final mech in mechs) {
                  base.parent!.element!.children.remove(mech);
                }
              }
            },
          },
        );
}
