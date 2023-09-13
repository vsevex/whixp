part of '../echo.dart';

/// Implements the PLAIN SASL authentication mechanism.
class SASLPlain extends SASL {
  /// Constructs a new instance of the `SASLPlain` class with the specified
  /// mechanism, client-first flag and priority.
  SASLPlain({
    /// Defaults to `PLAIN`. The name of the authentication mechanism.
    super.name = 'PLAIN',

    /// Whether client sends the first message in the authentication exchange.
    super.isClientFirst = true,

    /// The priority of the authentication mechanism.
    super.priority = 50,
  });

  /// Tests whether the client credentials are available for authentication.
  ///
  /// Returns `true` if the client credentials are available for authentication,
  /// `false` otherwise.
  @override
  bool test() => connection!._authcid != null;

  /// Generates a response to a SASL challenge.
  ///
  /// `connection` - The connection object to use for authentication.
  /// `challenge` - The challenge from the server.
  @override
  String onChallenge({String? challenge}) {
    if (connection!._domain == null) {
      throw Exception('SASLPlain onChallenge: domain is not defined!');
    }
    String auth = (connection!._authzid !=
            '${connection!._authcid}@${connection!._domain}')
        ? connection!._authzid!
        : '';
    auth = '$auth\u0000';
    auth = '$auth${connection!._authcid}';
    auth = '$auth\u0000';
    auth = '$auth${connection!._password}';
    return Echotils.utf16to8(auth);
  }
}
