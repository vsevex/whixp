part of '../stream/base.dart';

class Presence extends RootStanza {
  Presence({
    super.transport,
    Set<String>? showTypes,
    super.stanzaType,
    super.stanzaTo,
    super.stanzaFrom,
    super.receive = false,
    super.includeNamespace = false,
    super.getters,
    super.setters,
    super.deleters,
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.pluginMultiAttribute,
    super.pluginIterables,
    super.overrides,
    super.isExtension,
    super.setupOverride,
    super.boolInterfaces,
    super.element,
  }) : super(
          name: 'presence',
          namespace: Echotils.getNamespace('CLIENT'),
          pluginAttribute: 'presence',
          interfaces: <String>{
            'type',
            'to',
            'from',
            'id',
            'show',
            'status',
            'priority',
          },
          subInterfaces: <String>{'show', 'status', 'priority'},
          languageInterfaces: <String>{'status'},
          types: <String>{
            'available',
            'unavailable',
            'error',
            'probe',
            'subscribe',
            'subscribed',
            'unsubscribe',
            'unsubscribed',
          },
        ) {
    showtypes = showTypes ?? const {'dnd', 'chat', 'xa', 'away'};

    if (!this.receive && this['id'] == '') {
      if (transport != null) {
        this['id'] = Echotils.getUniqueId();
      }
    }

    addSetters(
      <Symbol, void Function(dynamic value, dynamic args, XMLBase base)>{
        const Symbol('type'): (value, args, base) {
          if (types.contains(value)) {
            base['show'] = null;
            if (value == 'available') {
              value = '';
            }
            base.setAttribute('type', value as String);
          } else if (showtypes.contains(value)) {
            base['show'] = value;
          }
        },
      },
    );

    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('type'): (args, base) {
        String out = base.getAttribute('type');
        if (out.isEmpty && showtypes.contains(base['show'])) {
          out = this['show'] as String;
        }
        if (out.isEmpty) {
          out = 'available';
        }
        return out;
      },
      const Symbol('priority'): (args, base) {
        int? priority;
        if ((base.getSubText('priority') as String).isNotEmpty) {
          priority = int.parse(base.getSubText('priority') as String);
        }
        return priority;
      },
    });

    addDeleters(
      <Symbol, void Function(dynamic args, XMLBase base)>{
        const Symbol('type'): (args, base) {
          base.deleteAttribute('type');
          base.deleteSub('show');
        },
      },
    );
  }

  late final Set<String> showtypes;
}
