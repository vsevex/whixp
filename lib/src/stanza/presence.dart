import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/stanza/root.dart';
import 'package:echox/src/stream/base.dart';

class Presence extends RootStanza {
  Presence({
    Set<String>? showTypes,
    super.stanzaType,
    super.stanzaTo,
    super.stanzaFrom,
    super.transport,
    super.receive = false,
    super.includeNamespace = false,
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
    _showtypes = showTypes ?? const {'dnd', 'chat', 'xa', 'away'};

    if (!receive && this['id'] == '') {
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
          } else if (_showtypes.contains(value)) {
            base['show'] = value;
          }
        },
      },
    );

    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('type'): (args, base) {
        String out = base.getAttribute('type');
        if (out.isEmpty && _showtypes.contains(base['show'])) {
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

  late final Set<String> _showtypes;
}
