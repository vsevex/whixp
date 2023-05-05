import 'package:echo/src/sasl.dart';

/// The `EXTERNAL` mechanism allows a client to request the server to use
/// credentials established by means external to the mechanism to authenticate
/// the cient. The `EXTERNAL` means may be, for instance, TSL services.
class SASLExternal extends SASL {
  /// Creates a new instance with the given optional three parameters. If no
  /// values provided, default values will be used.
  SASLExternal({
    /// A [String] that represents the SASL mechanism. It defaults to `EXTERNAL`
    super.mechanism = 'EXTERNAL',

    /// A [bool] that indicates whether the client sends the initial message
    /// in the SASL negatiatino. It default to `true`.
    super.isClientFirst = true,

    /// An [int] that indicates the priority of this SASL mechanism in the list
    /// of supported mechanisms. It defaults to `10`.
    super.priority = 10,
  });

  @override
  String onChallenge({String? challenge}) {
    /// According to XEP-178, an authzid SHOULD NOT be presented when the
    /// `authcid` contained or implied in the client certificate is the JID (i.e.
    /// authzid) with which the user wants to log in as.
    ///
    /// To NOT send the `authzid`, the user should therefore set the `authcid`
    /// equal to the JID when instantiating a new [EchoConnection] object.
    return connection!.authcid == connection!.authzid
        ? ''
        : connection!.authzid!;
  }
}
