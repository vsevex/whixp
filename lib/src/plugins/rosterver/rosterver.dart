import 'package:echox/src/plugins/base.dart';
import 'package:echox/src/plugins/rosterver/stanza.dart';
import 'package:echox/src/stream/base.dart';

class FeatureRosterVersioning extends PluginBase {
  FeatureRosterVersioning(this._features, {required super.base})
      : super('rosterversioning', description: 'Roster Versioning');

  final StanzaBase _features;

  @override
  void initialize() {
    final rosterver = RosterVersioning();

    base.registerFeature(
      'rosterver',
      (_) {
        print('roster version handling');
        return base.features.add('rosterver');
      },
      order: 9000,
    );

    _features.registerPlugin(rosterver);
  }
}
