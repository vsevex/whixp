part of '../../client.dart';

class FeatureStartTLS extends PluginBase {
  const FeatureStartTLS(this._features, {required super.base})
      : super(
          'starttls',
          description: 'Stream Feature: STARTTLS',
          dependencies: const {},
        );

  final StanzaBase _features;

  @override
  void initialize() {
    final proceed = _Proceed();
    final failure = _Failure();

    base.transport.registerHandler(
      FutureCallbackHandler(
        'STARTTLS Proceed',
        (_) => _handleStartTLSProceed(),
        matcher: XPathMatcher(proceed.tag),
      ),
    );
    base.registerFeature('starttls', _handleStartTLS, restart: true);
    base.transport.registerStanza(proceed);
    base.transport.registerStanza(failure);

    final startTLS = _StartTLS();
    registerStanzaPlugin(_features, startTLS);
    _features.enable(startTLS.name);
  }

  bool _handleStartTLS(StanzaBase features) {
    final stanza = _StartTLS();

    if (base.features.contains('starttls')) {
      return false;
    } else if (base.transport.disableStartTLS) {
      return false;
    } else {
      base.transport.send(Tuple2(stanza, null));
      return true;
    }
  }

  Future<void> _handleStartTLSProceed() async {
    if (await base.transport.startTLS()) {
      base.features.add('starttls');
    }
  }
}
