import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/stream/base.dart';

import 'package:xml/xml.dart' as xml;

class Session extends XMLBase {
  Session()
      : super(
          name: 'session',
          namespace: Echotils.getNamespace('SESSION'),
          interfaces: {'optional'},
          pluginAttribute: 'session',
        ) {
    addGetters(
      <Symbol, dynamic Function(dynamic args, XMLBase base)>{
        const Symbol('optional'): (args, base) {
          if (base.element!.getAttribute('xmlns') == namespace) {
            return base.element!.getElement('optional') != null;
          }
          return false;
        },
      },
    );

    addSetters(
      <Symbol, void Function(dynamic value, dynamic args, XMLBase base)>{
        const Symbol('optional'): (value, args, base) {
          if (value != null) {
            final optional = xml.XmlElement(xml.XmlName('optional'));
            base.element!.children.add(optional);
          } else {
            delete('optional');
          }
        },
      },
    );

    addDeleters(
      <Symbol, dynamic Function(dynamic args, XMLBase base)>{
        const Symbol('optional'): (args, base) {
          if (base.element!.getAttribute('xmlns') == namespace) {
            final optional = base.element!.getElement('optional');
            base.element!.children.remove(optional);
          }
        },
      },
    );
  }
}
