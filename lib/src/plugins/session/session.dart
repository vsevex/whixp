import 'package:meta/meta.dart';

import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

part 'stanza.dart';

class FeatureSession extends PluginBase {
  FeatureSession(this._features)
      : super('session', description: 'Start Session');

  final StanzaBase _features;
  late final IQ _iq;

  @override
  void initialize() {
    final session = Session();
    _iq = IQ(transport: base.transport);

    base.registerFeature('session', _handleSessionStart, order: 10001);

    _iq.registerPlugin(session);
    _features.registerPlugin(session);
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
    base.transport.emit('sessionStart');
  }
}
