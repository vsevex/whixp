import 'dart:typed_data';

import 'package:echox/echox.dart';
import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/plugins/base.dart';
import 'package:echox/src/sasl/sasl.dart';
import 'package:echox/src/stream/base.dart';

import 'package:xml/xml.dart' as xml;

part 'stanza/_auth.dart';

typedef SASLCallback = Map<String, String> Function(
  Set<String> required,
  Set<String> optional,
);
typedef SecurityCallback = Map<String, bool> Function(Set<String> values);

class FeatureMechanisms extends PluginBase {
  FeatureMechanisms({
    required super.base,
    this.saslCallback,
    this.securityCallback,
  }) : super('mechanisms');

  SASLCallback? saslCallback;
  SecurityCallback? securityCallback;
  final mechanisms = <String>[];
  late final attemptedMechanisms = <String>[];

  @override
  void initialize() {
    base.registerFeature(
      'mechanisms',
      _handleSASLAuth,
      restart: true,
      order: 100,
    );

    saslCallback ??= _defaultCredentials;
    securityCallback ??= _defaultSecurity;
  }

  bool _handleSASLAuth(StanzaBase stanza) {
    if (base.features.contains('mechanisms')) {
      return false;
    }

    mechanisms.addAll(stanza['mechanisms'] as List<String>);

    return _sendAuthentication();
  }

  Map<String, String> _defaultCredentials(
    Set<String> required,
    Set<String> optional,
  ) {
    final credentials = base.credentials;
    final results = <String, String>{};
    final params = <String>{...required, ...optional};

    for (final param in params) {
      if (param == 'username') {
        results[param] = credentials[param] ?? base.requestedJID.user;
      } else if (param == 'email') {
        final jid = base.requestedJID.bare;
        results[param] = credentials[param] ?? jid;
      } else if (param == 'host') {
        results[param] = base.requestedJID.domain;
      } else if (param == 'service') {
        results[param] = credentials[param] ?? 'xmpp';
      } else if (credentials.keys.contains(param)) {
        results[param] = credentials[param]!;
      }
    }

    return results;
  }

  Map<String, bool> _defaultSecurity(Set<String> values) {
    final result = <String, bool>{};

    for (final value in values) {
      if (value == 'encrypted') {
        if (base.features.contains('starttls')) {
          result[value] = true;
        } else if (base.transport.isConnectionSecured) {
          result[value] = true;
        } else {
          result[value] = false;
        }
      } else {
        /// TODO: get `value` from config.
      }
    }
    return result;
  }

  bool _sendAuthentication() {
    final mechList = mechanisms
      ..removeWhere((mech) => attemptedMechanisms.contains(mech));
    final saslTemp = SASLTemp(base);
    final mech = saslTemp.choose(mechList, saslCallback!, securityCallback!);

    final response = _Auth(transport: base.transport);
    response['mechanism'] = mech.name;

    try {
      response['value'] = mech.process();
    } catch (error) {
      attemptedMechanisms.add(mech.name);
      print(error);
    }

    response.send();

    return true;
  }
}
