import 'package:dartz/dartz.dart';

import 'package:echox/src/handler/callback.dart';
import 'package:echox/src/plugins/base.dart';
import 'package:echox/src/plugins/starttls/stanza.dart';
import 'package:echox/src/stream/base.dart';
import 'package:echox/src/stream/matcher/xpath.dart';

class FeatureStartTLS extends PluginBase {
  const FeatureStartTLS({required super.base})
      : super(
          'starttls',
          description: 'Stream Feature: STARTTLS',
          dependencies: const {},
        );

  @override
  void initialize() {
    final proceed = Proceed();
    final failure = Failure();

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
  }

  bool _handleStartTLS(StanzaBase features) {
    final stanza = StartTLS();

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
    print('starting TLS');
    if (await base.transport.startTLS()) {
      base.features.add('starttls');
    }
  }
}
