part of '../plugins/mechanisms/feature.dart';

class SASL {
  SASL(this._base) {
    _scram = Scram(_base);
    _registerMechanisms();
  }

  final WhixpBase _base;
  late final Scram _scram;

  final _mechanisms = <String, _Mechanism>{};

  /// Register a single [SASL] `mechanism`, to be supported by this client.
  void _registerMechanism(_Mechanism mechanism) =>
      _mechanisms[mechanism.name] = mechanism;

  /// Register the SASL `mechanisms` which will be supported by this instance of
  /// [EchoX] (i.e. which this XMPP client will support).
  void _registerMechanisms() {
    /// The list of all available authentication mechanisms.
    late final mechanismList = <_Mechanism>[
      _SASLAnonymous(_base),
      _SASLPlain(_base),
      _SASLSHA1(_base, scram: _scram),
      _SASLSHA256(_base, scram: _scram),
      _SASLSHA384(_base, scram: _scram),
      _SASLSHA512(_base, scram: _scram),
    ];
    mechanismList.map((mechanism) => _registerMechanism(mechanism)).toList();
  }

  /// Sorts a list of objects with prototype SASLMechanism according to their
  /// properties.
  List<_Mechanism?> _sortMechanismsByPriority(List<_Mechanism> mechanisms) {
    /// Iterate over all the available mechanisms.
    for (int i = 0; i < mechanisms.length - 1; i++) {
      int higher = i;
      for (int j = i + 1; j < mechanisms.length; ++j) {
        if (mechanisms[j].priority! > mechanisms[higher].priority!) {
          higher = j;
        }
      }
      if (higher != i) {
        final swap = mechanisms[i];
        mechanisms[i] = mechanisms[higher];
        mechanisms[higher] = swap;
      }
    }
    return mechanisms;
  }

  _Mechanism choose(
    Iterable<String> mechanisms,
    SASLCallback saslCallback,
    SecurityCallback securityCallback, [
    String? minimumMechanism,
  ]) {
    Set<String> availableMechanisms = _mechanisms.keys.toSet();
    availableMechanisms = Set<String>.from(availableMechanisms)
        .intersection(Set<String>.from(mechanisms));

    final filteredList = _sortMechanismsByPriority(
      _mechanisms.entries
          .where((entry) => availableMechanisms.contains(entry.key))
          .map((entry) => entry.value)
          .toList(),
    );

    final bestMech = filteredList.isEmpty ? null : filteredList.first;

    if (bestMech == null) {
      throw SASLException.noAppropriateMechanism();
    }

    try {
      final credentials = saslCallback(
        bestMech._requiredCredentials,
        bestMech._optionalCredentials,
      );

      final creds = <String>{'username', 'password', 'authzid'};
      for (final required in bestMech._requiredCredentials) {
        if (!credentials.containsKey(required)) {
          throw SASLException.missingCredentials(required);
        }
      }

      for (final optional in bestMech._optionalCredentials) {
        if (!credentials.containsKey(optional)) {
          credentials[optional] = '';
        }
      }

      for (final credential in credentials.entries) {
        if (creds.contains(credential.key)) {
          credentials[credential.key] =
              StringPreparationProfiles().saslPrep(credential.value);
        } else {
          credentials[credential.key] = credential.value;
        }
      }

      final securityOptions = securityCallback(bestMech._securityOptions);

      return bestMech.._setup(credentials, securityOptions.keys.toSet());
    } on Exception {
      rethrow;
    }
  }
}

class _SASLAnonymous extends _Mechanism {
  _SASLAnonymous(super.client) : super(name: 'ANONYMOUS', priority: 10);

  @override
  String process([String? challenge]) => 'Anonymous';

  @override
  String challenge(String challenge) {
    throw SASLException.unimplementedChallenge(name);
  }
}

class _SASLPlain extends _Mechanism {
  _SASLPlain(super.client)
      : super(
          name: 'PLAIN',
          priority: 50,
          requiredCredentials: {'username', 'password'},
          optionalCredentials: {'authzid'},
          securityOptions: <String>{
            'encrypted',
            'encryptedPlain',
            'unencryptedPlain',
          },
        );

  @override
  void _setup(Map<String, String> credentials, [Set<String>? securityOptions]) {
    super._setup(credentials, securityOptions);
    if (!_securityOptions.contains('encrypted')) {
      if (!_securityOptions.contains('unencryptedPlain')) {
        throw SASLException.cancelled('PLAIN without encryption');
      }
    } else {
      if (!_securityOptions.contains('encryptedPlain')) {
        throw SASLException.cancelled('PLAIN with encryption');
      }
    }
  }

  @override
  String process([String? challenge]) {
    final authzid = _base.credentials['authzid']!;
    final username = _base.credentials['username'];
    final password = _base.credentials['password'];

    String auth =
        (authzid != '$username@${_base.requestedJID.domain}') ? authzid : '';
    auth = '$auth\u0000';
    auth = '$auth$username';
    auth = '$auth\u0000';
    auth = '$auth$password';
    return Echotils.utf16to8(auth);
  }

  @override
  String challenge(String challenge) {
    throw SASLException.unimplementedChallenge(name);
  }
}

class _SASLSHA1 extends _Mechanism {
  _SASLSHA1(super.client, {required this.scram})
      : super(
          name: 'SCRAM-SHA-1',
          priority: 80,
          requiredCredentials: {'username', 'password'},
          optionalCredentials: {'authzid'},
          securityOptions: {'encrypted', 'unencryptedScram'},
        );

  final Scram scram;

  @override
  String process() => scram.clientChallenge();

  @override
  String challenge(String challenge) =>
      scram.scramResponse(challenge, 'SHA-1', 160);
}

class _SASLSHA256 extends _Mechanism {
  _SASLSHA256(super.client, {required this.scram})
      : super(
          name: 'SCRAM-SHA-256',
          priority: 70,
          requiredCredentials: {'username', 'password'},
          optionalCredentials: {'authzid'},
          securityOptions: {'encrypted', 'unencryptedScram'},
        );

  final Scram scram;

  @override
  String process() => scram.clientChallenge();

  @override
  String challenge(String challenge) =>
      scram.scramResponse(challenge, 'SHA-256', 256);
}

class _SASLSHA384 extends _Mechanism {
  _SASLSHA384(super.client, {required this.scram})
      : super(
          name: 'SCRAM-SHA-384',
          priority: 71,
          requiredCredentials: {'username', 'password'},
          optionalCredentials: {'authzid'},
          securityOptions: {'encrypted', 'unencryptedScram'},
        );

  final Scram scram;

  @override
  String process() => scram.clientChallenge();

  @override
  String challenge(String challenge) =>
      scram.scramResponse(challenge, 'SHA-384', 384);
}

class _SASLSHA512 extends _Mechanism {
  _SASLSHA512(super.client, {required this.scram})
      : super(
          name: 'SCRAM-SHA-512',
          priority: 72,
          requiredCredentials: {'username', 'password'},
          optionalCredentials: {'authzid'},
          securityOptions: {'encrypted', 'unencryptedScram'},
        );

  final Scram scram;

  @override
  String process() => scram.clientChallenge();

  @override
  String challenge(String challenge) =>
      scram.scramResponse(challenge, 'SHA-512', 512);
}
