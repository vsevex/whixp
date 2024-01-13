import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/utils/utils.dart';

part 'stanza.dart';

class FeaturePreApproval extends PluginBase {
  FeaturePreApproval(this._features)
      : super('preapproval', description: 'Subscription Pre-Approval');

  final StanzaBase _features;

  @override
  void pluginInitialize() {
    final preapproval = PreApproval();

    base.registerFeature(
      'preapproval',
      (_) {
        Log.instance.debug('Server supports subscription pre-approvals');
        return base.features.add('preapproval');
      },
      order: 9001,
    );

    _features.registerPlugin(preapproval);
  }

  /// Do not implement.
  @override
  void pluginEnd() {}

  /// Do not implement.
  @override
  void sessionBind(String? jid) {}
}
