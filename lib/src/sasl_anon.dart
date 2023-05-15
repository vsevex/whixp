import 'package:echo/src/sasl.dart';

/// This class extends the `SASL` and implements test method to check if
/// authentication mechanism is able to run. This class implements `SASL
/// ANONYMOUS` mechanism, which does not require any authentication
/// credentials from the client.
class SASLAnonymous extends SASL {
  /// Constructs a new instance of the `SASLAnonymous` class with the specified
  /// `mechanism`, `client-first` flag and `priority`.
  SASLAnonymous( {
    /// Equals mechanism name to `ANONYMOUS`.
    super.name = 'ANONYMOUS',

    /// False flag indicates if the client should send its response first.
    super.isClientFirst = false,

    /// The priority mechanism, which determines its order of use when selecting
    /// the best available mechanism.
    super.priority = 20,
  });

  /// Check if this mechanism is able to run by setting `authcid` property
  /// of the connection to `null`. This method returns `true` if the mechanism
  /// is able to run.
  @override
  bool test() {
    connection!.authcid = null;
    return super.test();
  }
}
