import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/utils/utils.dart';

part 'stanza.dart';

class FeatureRosterVersioning extends PluginBase {
  FeatureRosterVersioning()
      : super('rosterversioning', description: 'Roster Versioning');

  @override
  void pluginInitialize() => base.registerFeature(
        'rosterver',
        (_) {
          Log.instance.warning('Enabling roster versioning');
          return base.features.add('rosterver');
        },
        order: 9000,
      );

  /// Do not implement.
  @override
  void sessionBind(String? jid) {}

  /// Do not implement.
  @override
  void pluginEnd() {}
}
