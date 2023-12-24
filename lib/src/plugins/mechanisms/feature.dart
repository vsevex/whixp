import 'dart:math' as math;
import 'dart:typed_data';

import 'package:echox/echox.dart';
import 'package:echox/src/client.dart';
import 'package:echox/src/echotils/src/stringprep.dart';
import 'package:echox/src/handler/callback.dart';
import 'package:echox/src/plugins/base.dart';
import 'package:echox/src/plugins/mechanisms/stanza/stanza.dart';
import 'package:echox/src/sasl/scram.dart';
import 'package:echox/src/stream/base.dart';
import 'package:echox/src/stream/matcher/xpath.dart';

import 'package:xml/xml.dart' as xml;

part 'stanza/_auth.dart';
part 'stanza/_failure.dart';
part 'stanza/_challenge.dart';
part 'stanza/_response.dart';
part 'stanza/_success.dart';
part '../../sasl/sasl.dart';
part '../../sasl/mechanism.dart';

typedef SASLCallback = Map<String, String> Function(
  Set<String> required,
  Set<String> optional,
);
typedef SecurityCallback = Map<String, bool> Function(Set<String> values);

class FeatureMechanisms extends PluginBase {
  FeatureMechanisms(
    this._features, {
    required super.base,
    this.saslCallback,
    this.securityCallback,
    bool encryptedPlain = false,
    bool unencryptedPlain = false,
    bool unencryptedScram = true,
  }) : super('mechanisms', description: 'SASL') {
    _encryptedPlain = encryptedPlain;
    _unencryptedPlain = unencryptedPlain;
    _unencryptedScram = unencryptedScram;
  }

  final StanzaBase _features;

  SASLCallback? saslCallback;
  SecurityCallback? securityCallback;
  late final bool _encryptedPlain;
  late final bool _unencryptedPlain;
  late final bool _unencryptedScram;

  final mechanisms = <String>[];

  late final attemptedMechanisms = <String>[];
  late _Mechanism _mech;

  @override
  void initialize() {
    base.registerFeature(
      'mechanisms',
      _handleSASLAuth,
      restart: true,
      order: 100,
    );

    final challenge = _Challenge();
    final success = _Success();
    final failure = _Failure();

    base.transport
      ..registerHandler(
        CallbackHandler(
          'SASL Challenge',
          _handleChallenge,
          matcher: XPathMatcher(challenge.tag),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'SASL Success',
          _handleSuccess,
          matcher: XPathMatcher(success.tag),
        ),
      )
      ..registerHandler(
        CallbackHandler(
          'SASL Failure',
          _handleFailure,
          matcher: XPathMatcher(failure.tag),
        ),
      );

    base.transport
      ..registerStanza(_Auth())
      ..registerStanza(_Failure())
      ..registerStanza(challenge)
      ..registerStanza(_Response())
      ..registerStanza(success)
      ..registerStanza(failure);

    saslCallback ??= _defaultCredentials;
    securityCallback ??= _defaultSecurity;

    final mechanisms = Mechanisms();
    registerStanzaPlugin(_features, mechanisms);
    _features.enable(mechanisms.name);
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
        if (value == 'encryptedPlain') {
          result[value] = _encryptedPlain;
        } else if (value == 'unencryptedPlain') {
          result[value] = _unencryptedPlain;
        } else if (value == 'unencryptedScram') {
          result[value] = _unencryptedScram;
        } else {
          result[value] = false;
        }
      }
    }
    return result;
  }

  bool _handleSASLAuth(StanzaBase stanza) {
    if (base.features.contains('mechanisms')) {
      return false;
    }

    mechanisms.addAll(stanza['mechanisms'] as List<String>);

    return _sendAuthentication();
  }

  bool _sendAuthentication() {
    final mechList = mechanisms
      ..removeWhere((mech) => attemptedMechanisms.contains(mech));
    final sasl = SASL(base);

    try {
      _mech = sasl.choose(mechList, saslCallback!, securityCallback!);
    } on SASLException catch (error) {
      print(error);

      /// TODO: disconnect.
    } on StringPreparationException {
      /// TODO: disconnect.
    }

    final response = _Auth(transport: base.transport);
    response['mechanism'] = _mech.name;

    try {
      response['value'] = Echotils.btoa(_mech.process());
    } on SASLException {
      attemptedMechanisms.add(_mech.name);
      return _sendAuthentication();
    }

    response.send();

    return true;
  }

  void _handleChallenge(StanzaBase stanza) {
    final response = _Response(transport: base.transport);
    try {
      response['value'] = _mech.challenge(stanza['value'] as String);
    } on SASLException {
      /// TODO: disconnect.
    }
    response.send();
  }

  void _handleSuccess(StanzaBase stanza) {
    attemptedMechanisms.clear();
    base.features.add('mechanisms');
    base.transport.sendRaw(base.transport.streamHeader);
  }

  bool _handleFailure(StanzaBase stanza) {
    attemptedMechanisms.add(_mech.name);
    _sendAuthentication();
    return true;
  }
}
