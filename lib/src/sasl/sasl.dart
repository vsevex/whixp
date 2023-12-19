import 'dart:math' as math;

import 'package:echox/echox.dart';
import 'package:echox/src/client.dart';
import 'package:echox/src/echotils/src/stringprep.dart';
import 'package:echox/src/plugins/mechanisms/feature.dart';
import 'package:echox/src/stringprep/stringprep.dart';

/// Represents a SASL authentication mechanism in XMPP, providing a common
/// interface for SASL mechanisms to be implemented. This class has several
/// abstract methods and properties that must be implemented by concrete
/// subclass.
abstract class SASL {
  /// Constructor that accepts defined variables.
  SASL({required this.name, this.priority, this.isClientFirst});

  /// A [String] representing the name of the SASL mechanism.
  final String name;

  /// An [int] representing the priorityof the SASL mechanism.
  final int? priority;

  /// A [bool] indicating whether the client should send its response first
  /// without receiving a challenge from the server.
  final bool? isClientFirst;

  /// Connection late initializer.
  late EchoX? connection;

  /// A [bool] method indicating whether the SASL mechanism is able to run.
  ///
  /// * @param connection An [EchoX] object representing the XAMPP connection.
  bool test() => true;

  /// An abstract method that is called when the SASL mechanism receives a
  /// challenge from the server. This method should be implemented by concrete
  /// subclass to handle the specific SASL mechanism's response to [challenge]s.
  String onChallenge({String? challenge}) =>
      throw Exception('You should implement challenge handling!');

  /// A method that is called if the SASL mechanism is expected to send its
  /// response first without receiving a challenge from the server. This method
  /// should be overridden in concrete subclases if `isClientFirst` is `true`.
  String clientChallenge({String? testCNonce}) {
    if (!isClientFirst!) {
      throw Exception(
        'clientChallenge shoud not be called if isClientFirst is false!',
      );
    }
    return onChallenge();
  }

  /// A method that is called if SASL authentication fails.
  void onFailure() => connection = null;

  /// A method that is called if SASL authentication succeeds.
  void onSuccess() => connection = null;
}

abstract class Mechanism {
  Mechanism({
    required this.name,
    required this.base,
    int? priority,
    this.requiredCredentials = const <String>{},
    this.optionalCredentials = const <String>{},
    this.securityOptions = const <String>{},
  }) {
    if (priority == null) {
      this.priority = math.Random().nextInt(100) + 100;
    } else {
      this.priority = priority;
    }
  }

  final Whixp base;

  /// A [String] representing the name of the SASL mechanism.
  final String name;

  /// An [int] representing the priorityof the SASL mechanism.
  late final int? priority;

  final Set<String> requiredCredentials;
  final Set<String> optionalCredentials;
  final Set<String> securityOptions;

  void setup(Map<String, String> credentials, [Set<String>? securityOptions]) {
    if (securityOptions != null) {
      this.securityOptions.addAll(securityOptions);
    }
    base.credentials = credentials;
  }

  String process([List<int>? challenge]);
}

class SASLTemp {
  SASLTemp(this.base) {
    _registerMechanisms();
  }

  final Whixp base;

  final _mechanisms = <String, Mechanism>{};

  /// Register a single [SASL] `mechanism`, to be supported by this client.
  void _registerMechanism(Mechanism mechanism) =>
      _mechanisms[mechanism.name] = mechanism;

  /// Register the SASL `mechanisms` which will be supported by this instance of
  /// [EchoX] (i.e. which this XMPP client will support).
  void _registerMechanisms() {
    /// The list of all available authentication mechanisms.
    late final mechanismList = <Mechanism>[
      SASLTEMPAnonymous(base: base),
      SASLTEMPPlain(base: base),
    ];
    mechanismList.map((mechanism) => _registerMechanism(mechanism)).toList();
  }

  /// Sorts a list of objects with prototype SASLMechanism according to their
  /// properties.
  List<Mechanism?> _sortMechanismsByPriority(List<Mechanism> mechanisms) {
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

  Mechanism choose(
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

    final bestMech = filteredList.first;

    try {
      final credentials = saslCallback(
        bestMech!.requiredCredentials,
        bestMech.optionalCredentials,
      );

      final creds = <String>{'username', 'password', 'authzid'};
      for (final required in bestMech.requiredCredentials) {
        if (!credentials.containsKey(required)) {
          /// TODO: throw missing credential
        }
      }

      for (final optional in bestMech.optionalCredentials) {
        if (!credentials.containsKey(optional)) {
          credentials[optional] = '';
        }
      }

      for (final credential in credentials.entries) {
        if (creds.contains(credential.key)) {
          if (credential.value.isNotEmpty) {
            print(
              'mapping ${credential.value} c-1_2: ${StandaloneStringPreparation.inTablec12(credential.value)}',
            );
          }
          credentials[credential.key] =
              StringPreparationProfiles().saslPrep(credential.value);
        } else {
          credentials[credential.key] = credential.value;
        }
      }

      final securityOptions = securityCallback(bestMech.securityOptions);

      return bestMech..setup(credentials, securityOptions.keys.toSet());
    } catch (error) {
      rethrow;
      _mechanisms.removeWhere((key, value) => value == bestMech);
      return choose(_mechanisms.keys, saslCallback, securityCallback);
    }
  }
}

class SASLTEMPAnonymous extends Mechanism {
  SASLTEMPAnonymous({required super.base})
      : super(name: 'ANONYMOUS', priority: 20);

  @override
  String process([List<int>? challenge]) => 'Anonymous, Suelta';
}

class SASLTEMPPlain extends Mechanism {
  SASLTEMPPlain({required super.base})
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
  void setup(Map<String, String> credentials, [Set<String>? securityOptions]) {
    super.setup(credentials, securityOptions);
    if (!this.securityOptions.contains('encrypted')) {
      if (!this.securityOptions.contains('unencryptedPlain')) {
        throw SASLException.cancelled('PLAIN without encryption');
      }
    } else {
      if (!this.securityOptions.contains('encryptedPlain')) {
        throw SASLException.cancelled('PLAIN with encryption');
      }
    }
  }

  @override
  String process([List<int>? challenge]) {
    final authzid = base.credentials['authzid']!;
    final username = base.credentials['username'];
    final password = base.credentials['password'];

    String auth =
        (authzid != '$username@${base.requestedJID.domain}') ? authzid : '';
    auth = '$auth\u0000';
    auth = '$auth$username';
    auth = '$auth\u0000';
    auth = '$auth$password';
    return Echotils.utf16to8(auth);
  }
}
