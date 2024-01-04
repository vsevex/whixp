import 'package:echox/src/plugins/base.dart';
import 'package:echox/src/plugins/preapproval/stanza.dart';
import 'package:echox/src/stream/base.dart';

class FeaturePreApproval extends PluginBase {
  FeaturePreApproval(this._features, {required super.base})
      : super('preapproval', description: 'Subscription Pre-Approval');

  final StanzaBase _features;

  @override
  void initialize() {
    final preapproval = PreApproval();

    base.registerFeature(
      'preapproval',
      (_) {
        print('pre approval handling');
        return base.features.add('preapproval');
      },
      order: 9001,
    );

    _features.registerPlugin(preapproval);
  }
}
