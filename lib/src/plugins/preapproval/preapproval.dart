import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/utils/utils.dart';

part 'stanza.dart';

class FeaturePreApproval extends PluginBase {
  FeaturePreApproval()
      : super('preapproval', description: 'Subscription Pre-Approval');

  @override
  void pluginInitialize() => base.registerFeature(
        'preapproval',
        (_) {
          Log.instance.debug('Server supports subscription pre-approvals');
          return base.features.add('preapproval');
        },
        order: 9001,
      );

  /// Do not implement.
  @override
  void pluginEnd() {}

  /// Do not implement.
  @override
  void sessionBind(String? jid) {}
}
