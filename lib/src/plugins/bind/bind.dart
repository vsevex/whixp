import 'package:echox/src/jid/jid.dart';
import 'package:echox/src/plugins/base.dart';
import 'package:echox/src/plugins/bind/stanza.dart';
import 'package:echox/src/stanza/iq.dart';
import 'package:echox/src/stream/base.dart';

class FeatureBind extends PluginBase {
  FeatureBind(this._stanza, {required super.base})
      : super('bind', description: 'Resource Binding');

  final StanzaBase _stanza;
  StanzaBase? _features;
  late final IQ _iq;

  @override
  void initialize() {
    final bind = BindStanza();

    _iq = IQ(transport: base.transport);
    base.registerFeature('bind', _handleBindResource, order: 10000);
    registerStanzaPlugin(_iq, bind);

    registerStanzaPlugin(_stanza, bind);
    _stanza.enable(bind.name);
  }

  Future<void> _handleBindResource(StanzaBase stanza) async {
    _features = stanza;
    _iq['type'] = 'set';
    _iq.enable('bind');

    if (base.requestedJID.resource.isNotEmpty) {
      (_iq['bind'] as XMLBase)['resource'] = base.requestedJID.resource;
    }

    await _iq.sendIQ<void>(callback: _onBindResource);
  }

  void _onBindResource(StanzaBase response) {
    base.transport.boundJID = JabberIDTemp(
      (_iq.copy(response.element)['bind'] as XMLBase)['jid'] as String,
    );

    base.transport.sessionBind = true;

    base.features.add('bind');

    if (!(_features!['features'] as Map<String, XMLBase>)
        .containsKey('session')) {
      base.transport.sessionStarted = true;
    }
  }
}
