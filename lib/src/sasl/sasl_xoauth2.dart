part of '../echo.dart';

/// Provides authentication using an OAuth2 token.
class SASLXOAuth2 extends SASL {
  /// Constructs a new instance of the `SASLXOAuth2` class with the specified
  /// mechanism, client-first flag and priority.
  SASLXOAuth2({
    /// The SASL mechanism name
    super.name = 'X-OAUTH2',

    /// A flag indicating whether the client sends the first message
    super.isClientFirst = true,

    /// The priority of the SASL mechanism
    super.priority = 30,
  });

  /// A method that returns a [bool] indicating whether the authentication
  /// credentials have been set. In this case, it returns true if the password
  /// property of the connection object is not null.
  @override
  bool test() => connection!._password != null;

  /// A method that generates the response for a given challenge. In this case,
  /// it constructs a string that contains the authorization identity (if set),
  /// a null character, the authentication identity (if set), another null
  /// character, and the OAuth2 token.
  @override
  String onChallenge({String? challenge}) {
    String auth = '\u0000';
    if (connection!._authcid != null) {
      auth += connection!._authzid!;
    }
    auth += '\u0000';
    auth += connection!._password.toString();

    /// The string is then converted from UTF-16 to UTF-8 format and returned
    /// as the response.
    return Echotils.utf16to8(auth);
  }
}
