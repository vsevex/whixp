import 'dart:collection';

import 'package:whixp/src/exception.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/features.dart';
import 'package:whixp/src/sasl/sasl.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/stanza/node.dart';
import 'package:whixp/src/transport.dart';
import 'package:whixp/src/utils/utils.dart';
import 'package:whixp/src/whixp.dart';

import 'package:xml/xml.dart' as xml;

part 'stanza/_auth.dart';
part 'stanza/_failure.dart';
part 'stanza/_challenge.dart';
part 'stanza/_response.dart';
part 'stanza/_success.dart';

typedef SASLCallback = Map<String, String?> Function(
  Set<String> required,
  Set<String> optional,
);

typedef SecurityCallback = Map<String, bool> Function(Set<String> values);

const String _namespace = 'urn:ietf:params:xml:ns:xmpp-sasl';
const String _challenge = 'sasl:challenge';
const String _response = 'sasl:response';
const String _success = 'sasl:success';
const String _failure = 'sasl:failure';

class FeatureMechanisms {
  FeatureMechanisms(
    this.whixp, {
    this.saslCallback,
    this.securityCallback,
    bool encryptedPlain = false,
    bool unencryptedPlain = false,
    bool unencryptedScram = true,
  }) {
    _encryptedPlain = encryptedPlain;
    _unencryptedPlain = unencryptedPlain;
    _unencryptedScram = unencryptedScram;
  }

  final WhixpBase whixp;

  SASLCallback? saslCallback;
  SecurityCallback? securityCallback;

  late final bool _encryptedPlain;
  late final bool _unencryptedPlain;
  late final bool _unencryptedScram;

  final mechanisms = <String>{};

  final attemptedMechanisms = <String>{};
  late Mechanism _mech;

  void pluginInitialize() {
    Transport.instance()
      ..registerHandler(
        Handler('SASL Challenge', _handleChallenge)..packet(_challenge),
      )
      ..registerHandler(
        Handler('SASL Success', _handleSuccess)..packet(_success),
      )
      ..registerHandler(
        Handler('SASL Failure', _handleFailure)..packet(_failure),
      );

    saslCallback ??= _defaultCredentials;
    securityCallback ??= _defaultSecurity;
  }

  Map<String, String?> _defaultCredentials(
    Set<String> required,
    Set<String> optional,
  ) {
    final credentials = whixp.credentials;
    final results = <String, String?>{};
    final params = <String>{...required, ...optional};

    for (final param in params) {
      if (param == 'username') {
        results[param] = credentials[param] ?? whixp.requestedJID?.user;
      } else if (param == 'email') {
        final jid = whixp.requestedJID?.bare;
        results[param] = credentials[param] ?? jid;
      } else if (param == 'host') {
        results[param] =
            whixp.requestedJID?.domain ?? whixp.transport.address.firstValue;
      } else if (param == 'service-name') {
        results[param] = Transport.instance().connection.serviceName;
      } else if (param == 'service') {
        results[param] = credentials[param] ?? 'xmpp';
      } else if (credentials.keys.contains(param)) {
        results[param] = credentials[param];
      }
    }

    /// Remove all empty values from the results.
    results.removeWhere((_, param) => param?.isEmpty ?? true);

    return results;
  }

  Map<String, bool> _defaultSecurity(Set<String> values) {
    final result = <String, bool>{};

    for (final value in values) {
      if (value == 'encrypted') {
        if (StreamFeatures.supported.contains('starttls')) {
          result[value] = true;
        } else if (Transport.instance().isConnectionSecured) {
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

  bool handleSASLAuth(Packet features) {
    if (StreamFeatures.supported.contains('mechanisms')) return false;
    if (features is! StreamFeatures) return false;
    mechanisms.addAll(features.mechanisms?.list ?? <String>{});

    return _sendAuthentication();
  }

  bool _sendAuthentication() {
    final mechList = mechanisms
      ..removeWhere((mech) => attemptedMechanisms.contains(mech));
    final sasl = SASL(whixp);

    try {
      _mech = sasl.choose(mechList, saslCallback!, securityCallback!);
    } on SASLException catch (error) {
      if (error.message.contains('Missing credential')) {
        if (error.extra is Mechanism) {
          _mech = error.extra as Mechanism;
          return _processFailure();
        }
      }

      Log.instance
          .error('No appropriate login method found. Aborting connection...');

      Transport.instance().disconnect(consume: false);
      return false;
    } on StringPreparationException {
      Log.instance.error('A credential value did not pass SASL preperation');

      Transport.instance().disconnect(consume: false);
      return false;
    }

    String? body;

    try {
      body = WhixpUtils.btoa(_mech.process());
    } on SASLException {
      attemptedMechanisms.add(_mech.name);
      return _sendAuthentication();
    }

    Transport.instance().send(_Auth(mechanism: _mech.name, body: body));

    return true;
  }

  void _handleChallenge(Packet challenge) {
    if (challenge is! SASLChallenge) return;
    String? body;
    try {
      body = _mech.challenge(challenge.body!);
    } on SASLException {
      /// Disconnect s if there is any [SASLException] occures.
      Transport.instance().disconnect();
      return;
    }
    Transport.instance().send(SASLResponse(body: body));
  }

  void _handleSuccess(Packet success) {
    if (success is! SASLSuccess) return;
    attemptedMechanisms.clear();
    StreamFeatures.supported.add('mechanisms');
    Transport.instance().sendRaw(Transport.instance().streamHeader);
  }

  bool _handleFailure(Packet failure) {
    if (failure is! SASLFailure) return false;
    return _processFailure(failure: failure);
  }

  bool _processFailure({Packet? failure}) {
    attemptedMechanisms.add(_mech.name);
    if (failure != null && failure is SASLFailure) {
      Log.instance.info(
        'Authentication failed: ${failure.reason}, mechanism: ${_mech.name}',
      );
    } else {
      Log.instance
          .info('Authentication failed with the mechanism: ${_mech.name}');
    }
    Transport.instance().emit<String>(
      'failedAuthentication',
      data: (failure as SASLFailure?)?.reason ?? '${_mech.name} failed',
    );
    _sendAuthentication();
    return true;
  }
}
