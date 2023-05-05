import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:echo/src/log.dart';
import 'package:echo/src/utils.dart';

/// [Scram] is a singleton class used for the SCRAM (Saited Challenge Response
/// Authentication Mechanism) authentication in the XMPP protocol. It has a
/// private constructor and a factory method that returns the constant instance
/// of the class.
class Scram {
  /// Factory method which returns private instance of this class.
  factory Scram() => _instance;

  /// Private constructor of the class.
  const Scram._();

  /// Constant instance of private constructor.
  static const Scram _instance = Scram._();

  /// Parses SCRAM challenge string and returns a [Map] of three values,
  /// including the `nonce`, `salt`, and `iteration` count, if they exist
  /// in the challenge string. Otherwise, it returns null if any of these values
  /// is missing or invalid.
  ///
  /// `challenge`: The SCRAM challenge string to parse.
  static Map<String, dynamic>? scramParseChallenge(String? challenge) {
    /// A [String] representing the server's `nonce` value.
    String? nonce;

    /// A [List] of integers representing `salt` value received from the server.
    List<int>? salt;

    /// An [int] representing the number of iterations to perform during key
    /// derivation.
    int? iter;

    /// If challenge is null, then return the function.
    if (challenge == null) return null;

    /// An attribute for matching attribute-value pairs of the passed challenge.
    final attribute = RegExp(r'([a-z]+)=([^,]+)(,|$)');

    /// Equal to new variable passed challenge due the iteration of its
    /// content.
    String passedChallenge = challenge;

    /// Loop through the challenge string, matching and extracting
    /// attribute-value pairs using the regular expression.
    while (attribute.hasMatch(passedChallenge)) {
      final matches = attribute.firstMatch(passedChallenge);
      passedChallenge = passedChallenge.replaceFirst(matches![0]!, "");

      switch (matches[1]) {
        case 'r':
          nonce = matches[2];
          break;
        case 's':
          salt = Utils.base64ToArrayBuffer(matches[2]!);
          break;
        case 'i':
          iter = int.parse(matches[2]!, radix: 10);
          break;
        default:
          return null;
      }
    }

    /// If the iteration count is less than 4096, log a warning message and
    /// return `null`.
    if (iter == null || iter < 4096) {
      Log().warn(
        'Failing SCRAM autnentication because server supplied iteration count < 4096.',
      );
      return null;
    }

    /// If the salt value is not present, log a warning message and return
    /// `null`.
    if (salt == null) {
      Log().warn(
        'Failing SCRAM authentication because server supplied incorrect salt.',
      );
      return null;
    }

    /// Return a Map containing the `nonce`, `salt`, and `iter` values.
    return {'nonce': nonce, 'salt': salt, 'iter': iter};
  }

  Future<Map<String, dynamic>> scramDeriveKeys(
    String password,
    Uint8List salt,
    int iterations,
    String hashName,
    int hashBits,
    String nonce,
  ) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha1(),
      bits: hashBits ~/ 8,
      iterations: iterations,
    );
    final saltedPasswordBits = await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: Utils.stringToArrayBuffer(nonce),
    );
    final saltedPassword = HMac(SHA1Digest(), hashBits ~/ 8)
      ..init(KeyParameter(saltedPasswordBits.));

    return {
      'ck': await sign(saltedPassword, 'Client Key'),
      'sk': await sign(saltedPassword, 'Server Key'),
    };
  }
}

Future<Uint8List> sign(Mac mac, String data) async =>
    mac.(Utils.stringToArrayBuffer(data));
