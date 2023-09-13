part of '../echox.dart';

/// The [SASLSHA256] class is a concrete implementation of the [SASL] abstract
/// class, which provides a framework for implementing different SASL
/// mechanisms. This class specifically implements the `SCRAM-SHA-256`
/// mechanism, which is a SASL authentication mechanism that uses the `Secure
/// Hash Algorithm 256` (SHA-256) to provide message authentication.
class SASLSHA256 extends SASL {
  /// Constructs a new instance of the `SASLSHA256` class with the specified
  /// mechanism, client-first flag and priority.
  SASLSHA256({
    /// The SASL mechanism name
    super.name = 'SCRAM-SHA-256',

    /// A flag indicating whether the client sends the first message
    super.isClientFirst = true,

    /// The priority of the SASL mechanism
    super.priority = 70,
  });

  /// The `test` method checks if the connection's authcid (authentication
  /// identity) is not null. If it is null, it returns false, indicating that
  /// this SASL mechanism cannot be used for authentication.
  @override
  bool test() => connection!._authcid != null;

  /// The `onChallenge` method is called when the server sends a challenge to
  /// the client. This method uses the [Scram] utility class to generate a
  /// response to the challenge using the `scramResponse` method, passing in
  /// the connection, the challenge, the hash algorithm (SHA-256), and the hash
  /// length (256 bits).
  @override
  String onChallenge({String? challenge}) =>
      Scram().scramResponse(connection!, challenge, 'SHA-256', 256)!;

  /// This method generates and returns the client's first message. It uses the
  /// [Scram] utility class to generate the message using the `clientChallenge`
  /// method, passing in the connection and an optional test client nonce
  /// (testCNonce). The client's first message consists of the authentication
  /// identity (n), an empty authentication authorization identity (""), and a
  /// client nonce (r), separated by commas.
  ///
  /// The authentication authorization identity is empty because this SASL
  /// mechanism does not support authorization identity. The client nonce is
  /// generated by the generate_cnonce function in the [Scram] utility class,
  /// unless a test client nonce is provided.
  @override
  String clientChallenge({String? testCNonce}) =>
      Scram.clientChallenge(connection!, testCNonce);
}
