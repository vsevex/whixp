import 'dart:async';

import 'package:echox/src/handler/callback.dart';
import 'package:echox/src/plugins/mechanisms/feature.dart';
import 'package:echox/src/plugins/mechanisms/stanza/stanza.dart';
import 'package:echox/src/plugins/starttls/stanza.dart';
import 'package:echox/src/plugins/starttls/starttls.dart';
import 'package:echox/src/stanza/features.dart';
import 'package:echox/src/stream/base.dart';
import 'package:echox/src/stream/matcher/xpath.dart';
import 'package:echox/src/whixp.dart';

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
        "<stream:stream to='${boundJID.host}' xmlns:stream='$streamNamespace' xmlns='$defaultNamespace' xml:lang='$language' version='1.0'>";

    transport
      ..registerStanza(StreamFeatures())
      ..registerHandler(
        FutureCallbackHandler(
          'Stream Features',
          (stanza) async {
            _registerStanzas(stanza);
            await _handleStreamFeatures(stanza);
            return;
          },
          matcher: XPathMatcher('<features xmlns="$streamNamespace"/>'),
        ),
      );

    registerPlugin('starttls', FeatureStartTLS(base: this));
    registerPlugin('mechanisms', FeatureMechanisms(base: this));
  }

  void reset() {
    streamFeatureHandlers.clear();
  }

  /// Default language to use in stanza communication.
  final String language;

  void _registerStanzas(StanzaBase stanza) {
    if (stanza.payload.first.name.qualified == 'starttls') {
      final starttls = StartTLS();
      registerStanzaPlugin(stanza, starttls);
      stanza.enable(starttls.name);
    }
    if (stanza.payload.first.name.qualified == 'mechanisms') {
      final mechanisms = Mechanisms();
      registerStanzaPlugin(stanza, mechanisms);
      stanza.enable(mechanisms.name);
    }
  }

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
