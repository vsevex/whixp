import 'package:meta/meta.dart';

import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/utils/utils.dart';

part 'stanza.dart';

class FeatureBind extends PluginBase {
  FeatureBind(this._stanza) : super('bind', description: 'Resource Binding');

  StanzaBase? _features;

  final StanzaBase _stanza;
  late final IQ _iq;

  @override
  void initialize() {
    final bind = BindStanza();

    _iq = IQ(transport: base.transport);
    base.registerFeature('bind', _handleBindResource, order: 10000);
    _iq.registerPlugin(bind);

    _stanza.registerPlugin(bind);
    _stanza.enable(bind.name);
  }

  Future<void> _handleBindResource(StanzaBase stanza) async {
    _features = stanza;
    _iq['type'] = 'set';
    _iq.enable('bind');

    if (base.requestedJID.resource.isNotEmpty) {
      (_iq['bind'] as XMLBase)['resource'] = base.requestedJID.resource;
    }

    await _iq.sendIQ<void>(callback: _onBindResponse);
  }

  void _onBindResponse(StanzaBase response) {
    base.transport.boundJID = JabberID(
      (_iq.copy(element: response.element)['bind'] as XMLBase)['jid'] as String,
    );

    base.transport.sessionBind = true;
    base.transport
        .emit<String>('sessionBind', data: base.transport.boundJID.toString());

    base.features.add('bind');

    if (!(_features!['features'] as Map<String, XMLBase>)
        .containsKey('session')) {
      base.transport.sessionStarted = true;
      base.transport.emit('sessionStart');
    }
  }
}
