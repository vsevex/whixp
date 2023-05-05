import 'package:echo/src/sasl.dart';
import 'package:echo/src/utils.dart';

/// This class represents the implementation of the SASL OAuthBearer
/// authentication mechanism. It extend sthe `SASL` class and overrides its
/// `test` and `onChallenge` methods.
class SASLOAuthBearer extends SASL {
  /// Constructs an instance of `SASLOAuthBearer` with the given `mechanism`,
  /// `isClientFirst`, and `priority` parameters.
  SASLOAuthBearer({
    /// A read-only property that represents the mechanism used for
    /// authentication, which is always set to `OAUTHBEARER`.
    super.mechanism = 'OAUTHBEARER',

    /// A read-only property that indicates whether the client should send its
    /// credentials to the server before receiving a challenge from it, which
    /// is always set to `true`.
    super.isClientFirst = true,

    /// A read-only property that indicates the priority of the mechanism
    /// compared to other SASL mechanisms.
    super.priority = 40,
  });

  /// Overrides the `test` method of the `SASL` class and returns `true` if
  /// the `password` property of the `connection` object is not null, indicating
  /// that the client has provided its credentials.
  @override
  bool test() => connection!.password != null;

  /// Returns a string containing the authentication information to be sent to
  /// the server. The authentication information is in the format of an OAUTH2
  /// berarer token. If the `authcid` property of the `connection` object is
  /// not null, it is included in the authentiation information as an
  /// authorization ID.
  @override
  String onChallenge({String? challenge}) {
    String auth = 'n,';
    if (connection!.authcid != null) {
      auth = '${auth}a=${connection!.authzid}';
    }
    auth = '$auth,';
    auth = '$auth\u0001';
    auth = '${auth}auth=Bearer';
    auth = '$auth${connection!.password}';
    auth = '$auth\u0001';
    auth = '$auth\u0001';

    /// The authentication information is returned as a UTF-8 encoded string.
    return Utils.utf16to8(auth);
  }
}
