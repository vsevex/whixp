import 'dart:async';

import 'package:dartz/dartz.dart';

import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/handler/callback.dart';
import 'package:echox/src/plugins/base.dart';
import 'package:echox/src/plugins/bind/bind.dart';
import 'package:echox/src/plugins/mechanisms/feature.dart';
import 'package:echox/src/plugins/preapproval/preapproval.dart';
import 'package:echox/src/plugins/rosterver/rosterver.dart';
import 'package:echox/src/plugins/session/session.dart';
import 'package:echox/src/stanza/features.dart';
import 'package:echox/src/stream/base.dart';
import 'package:echox/src/stream/matcher/xpath.dart';
import 'package:echox/src/whixp.dart';

part 'plugins/starttls/starttls.dart';
part 'plugins/starttls/stanza.dart';

class Whixp extends WhixpBase {
  Whixp(
    String jabberID,
    String password, {
    super.host,
    super.port,
    super.useIPv6,
    super.useTLS = true,
    super.disableStartTLS,
    super.certs,
    this.language = 'en',
    super.connectionTimeout,
  }) : super(jabberID: jabberID) {
    setup();

    credentials.addAll({'password': password});
  }

  void setup() {
    reset();

    /// Set [streamHeader] of declared transport for initial send.
    transport.streamHeader =
        "<stream:stream to='${transport.boundJID.host}' xmlns:stream='$streamNamespace' xmlns='$defaultNamespace' xml:lang='$language' version='1.0'>";

    StanzaBase features = StreamFeatures();

    registerPlugin('bind', FeatureBind(features, base: this));
    registerPlugin('session', FeatureSession(features, base: this));
    registerPlugin('starttls', FeatureStartTLS(features, base: this));
    registerPlugin('mechanisms', FeatureMechanisms(features, base: this));
    registerPlugin(
      'rosterversioning',
      FeatureRosterVersioning(features, base: this),
    );
    registerPlugin('preapproval', FeaturePreApproval(features, base: this));

    transport
      ..registerStanza(features)
      ..registerHandler(
        FutureCallbackHandler(
          'Stream Features',
          (stanza) async {
            features = features.copy(stanza.element);
            _handleStreamFeatures(features);
            return;
          },
          matcher: XPathMatcher('<features xmlns="$streamNamespace"/>'),
        ),
      );

    transport.defaultLanguage = language;
  }

  void reset() {
    streamFeatureHandlers.clear();
  }

  /// Default language to use in stanza communication.
  final String language;

  final saslData = <String, dynamic>{};

  Future<bool> _handleStreamFeatures(StanzaBase features) async {
    for (final feature in streamFeatureOrder) {
      final name = feature.value2;

      if ((features['features'] as Map<String, XMLBase>).containsKey(name) &&
          (features['features'] as Map<String, XMLBase>)[name] != null) {
        final handler = streamFeatureHandlers[name]!.value1;
        final restart = streamFeatureHandlers[name]!.value2;

        final result = await handler(features);

        if (result != null && restart) {
          return true;
        }
      }
    }

    return false;
  }

  void connect() {
    transport.connect();
  }

  String get password => credentials['password']!;
}
