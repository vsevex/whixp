part of '../plugins/mechanisms/feature.dart';

abstract class _Mechanism {
  _Mechanism(
    this._base, {
    required this.name,
    int? priority,
    Set<String>? requiredCredentials,
    Set<String>? optionalCredentials,
    Set<String>? securityOptions,
  }) {
    if (priority == null) {
      this.priority = math.Random().nextInt(100) + 100;
    } else {
      this.priority = priority;
    }

    _requiredCredentials = requiredCredentials ?? <String>{};
    _optionalCredentials = optionalCredentials ?? <String>{};
    _securityOptions = securityOptions ?? <String>{};
  }

  final WhixpBase _base;

  /// A [String] representing the name of the SASL mechanism.
  final String name;

  /// An [int] representing the priorityof the SASL mechanism.
  late final int? priority;

  late final Set<String> _requiredCredentials;
  late final Set<String> _optionalCredentials;
  late final Set<String> _securityOptions;

  void _setup(Map<String, String> credentials, [Set<String>? securityOptions]) {
    if (securityOptions != null) {
      _securityOptions.addAll(securityOptions);
    }
    _base.credentials = credentials;
  }

  String process();

  String challenge(String challenge);
}
