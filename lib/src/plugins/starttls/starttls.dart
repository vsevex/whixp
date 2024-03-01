import 'package:meta/meta.dart';

import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/stream/matcher/matcher.dart';
import 'package:whixp/src/utils/utils.dart';

part 'stanza.dart';

class FeatureStartTLS extends PluginBase {
  FeatureStartTLS()
      : super(
          'starttls',
          description: 'Stream Feature: STARTTLS',
        );

  @override
  void pluginInitialize() {
    final proceed = Proceed();
    final failure = Failure();

    base.transport.registerHandler(
      FutureCallbackHandler(
        'STARTTLS Proceed',
        (_) => _handleStartTLSProceed(),
        matcher: XPathMatcher(proceed.tag),
      ),
    );
    base.registerFeature('starttls', _handleStartTLS, restart: true, order: 0);
    base.transport.registerStanza(proceed);
    base.transport.registerStanza(failure);
  }

  /// Handle notification that the server supports TLS.
  bool _handleStartTLS(StanzaBase features) {
    final stanza = StartTLS();

    if (base.features.contains('starttls')) {
      return false;
    } else if (base.transport.disableStartTLS) {
      return false;
    } else {
      base.transport.send(stanza);
      return true;
    }
  }

  /// Restart the XML stream when TLS is accepted.
  Future<void> _handleStartTLSProceed() async {
    if (await base.transport.startTLS()) {
      base.features.add('starttls');
    }
  }

  /// Do not implement.
  @override
  void pluginEnd() {}

  /// Do not implement.
  @override
  void sessionBind(String? jid) {}
}
