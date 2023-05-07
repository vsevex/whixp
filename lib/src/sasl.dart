import 'package:echo/src/connection.dart';

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

  /// An [EchoConnection] object representing the XAMPP connection.
  EchoConnection? connection;

  /// A [bool] method indicating whether the SASL mechanism is able to run.
  bool test() => true;

  /// An abstract method that is called when the SASL mechanism receives a
  /// challenge from the server. This method should be implemented by concrete
  /// subclass to handle the specific SASL mechanism's response to challenges.
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
