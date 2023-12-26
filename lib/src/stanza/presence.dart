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

    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('type'): (args, base) {
        String? out = base.getAttribute('type');
        if (out != null && _showtypes.contains(out)) {
          out = this['show'] as String;
        }
        if (out == null || out.isEmpty) {
          out = 'available';
        }
        return out;
      },
      const Symbol('priority'): (args, base) {
        final presence = int.parse(base.getSubText('priority') as String);
        return presence;
      },
    });
  }

  late final Set<String> _showtypes;
}
