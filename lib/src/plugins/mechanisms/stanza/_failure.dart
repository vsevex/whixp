part of '../feature.dart';

class _Failure extends StanzaBase {
  _Failure()
      : super(
          name: 'failure',
          namespace: WhixpUtils.getNamespace('SASL'),
          interfaces: {'condition', 'text'},
          pluginAttribute: 'failure',
          subInterfaces: {'text'},
        ) {
    addGetters(
      <Symbol, dynamic Function(dynamic args, XMLBase base)>{
        const Symbol('condition'): (args, base) {
          for (final child in base.element!.childElements) {
            final condition = child.qualifiedName;
            if (_conditions.contains(condition)) {
              return condition;
            }
          }
          return 'not-authorized';
        },
      },
    );

    addSetters(
      <Symbol, void Function(dynamic value, dynamic args, XMLBase base)>{
        const Symbol('condition'): (value, args, base) {
          if (_conditions.contains(value)) {
            base.delete('condition');
            base.element!.children
                .add(xml.XmlElement(xml.XmlName(value as String)));
          }
        },
      },
    );

    addDeleters(
      <Symbol, dynamic Function(dynamic args, XMLBase base)>{
        const Symbol('condition'): (args, base) {
          for (final child in base.element!.children) {
            final condition = child.innerText;
            if (_conditions.contains(condition)) {
              base.element!.children.remove(child);
            }
          }
        },
      },
    );
  }

  @override
  bool setup([xml.XmlElement? element]) {
    if (element != null) {
      this['condition'] = 'not-authorized';
    }
    return super.setup(element);
  }

  final _conditions = <String>{
    'aborted',
    'account-disabled',
    'credentials-expired',
    'encryption-required',
    'incorrect-encoding',
    'invalid-authzid',
    'invalid-mechanism',
    'malformed-request',
    'mechansism-too-weak',
    'not-authorized',
    'temporary-auth-failure',
  };
}
