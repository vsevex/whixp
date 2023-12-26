import 'package:echox/src/plugins/base.dart';
import 'package:echox/src/plugins/session/stanza.dart';
import 'package:echox/src/stanza/iq.dart';
import 'package:echox/src/stream/base.dart';

class FeatureSession extends PluginBase {
  FeatureSession(this._features, {required super.base})
      : super('session', description: 'Start Session');

  final StanzaBase _features;
  late final IQ _iq;

  @override
  void initialize() {
    final session = Session();
    _iq = IQ(transport: base.transport);

    base.registerFeature('session', _handleSessionStart);

    registerStanzaPlugin(_iq, session);
    registerStanzaPlugin(_features, session);
  }

  Future<void> _handleSessionStart(StanzaBase features) async {
    if ((features['session'] as XMLBase)['optional'] as bool) {
      base.transport.sessionStarted = true;
      base.transport.emit('sessionStart');
      return;
    }

    _iq['type'] = 'set';
    _iq.enable('session');
    await _iq.sendIQ(callback: _onStartSession);
  }

  void _onStartSession(StanzaBase response) {
    base.features.add('session');

    base.transport.sessionStarted = true;
  }
}
