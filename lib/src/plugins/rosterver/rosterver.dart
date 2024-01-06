import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/utils/utils.dart';

part 'stanza.dart';

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
        base.logger.warning('Enabling roster versioning');
        return base.features.add('rosterver');
      },
      order: 9000,
    );

    _features.registerPlugin(rosterver);
  }
}
