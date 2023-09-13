part of '../echo.dart';

/// This class is a sub-class of the [SASL] class and provides a `Secure
/// Challenge Response Authentication Mechanism` (SCRAM) implementation for the
/// SHA-512 hash algorithm.
class SASLSHA512 extends SASL {
  /// Constructs a new instance of the `SASLSHA512` class with the specified
  /// mechanism, client-first flag and priority.
  SASLSHA512({
    /// The SASL mechanism name
    super.name = 'SCRAM-SHA-512',

    /// A flag indicating whether the client sends the first message
    super.isClientFirst = true,

    /// The priority of the SASL mechanism
    super.priority = 72,
  });

  /// Checks whether the SASL mechanism can be used for authentication.
  @override
  bool test() => connection!._authcid != null;

  /// Generates a SCRAM response to the server's challenge.
  @override
  String onChallenge({String? challenge}) =>
      Scram().scramResponse(connection!, challenge, 'SHA-512', 512)!;

  /// Generates the client's first message in the authentication process.
  @override
  String clientChallenge({String? testCNonce}) =>
      Scram.clientChallenge(connection!, testCNonce);
}
