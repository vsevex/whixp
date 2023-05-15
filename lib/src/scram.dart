import 'dart:math' as math;

import 'dart:typed_data';

import 'package:echo/src/echo.dart';
import 'package:echo/src/log.dart';
import 'package:echo/src/utils.dart';

import 'package:pointycastle/export.dart';

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

  /// This method is used to generate the proof of the client's identity to the
  /// server, which is required for the SCRAM authentication mechanism. Without
  /// this method, the authentication process cannot be completed successfully.
  static Uint8List clientProof(
    /// The message to be signed by the client
    String message,

    /// The name of the hash function to be used in the HMAC operation
    String hashName,

    /// The key to be used in the HMAC operation
    Uint8List clientKey,
  ) {
    final storedKey = HMac(_getDigest(hashName), clientKey.length)
      ..init(KeyParameter(clientKey));

    final signature = storedKey.process(Utils.stringToArrayBuffer(message));

    return Utils.xorUint8Lists(clientKey, signature);
  }

  /// Parses SCRAM challenge string and returns a [Map] of three values,
  /// including the `nonce`, `salt`, and `iteration` count, if they exist
  /// in the challenge string. Otherwise, it returns null if any of these values
  /// is missing or invalid.
  ///
  /// `challenge`: The SCRAM challenge string to parse.
  static Map<String, dynamic>? parseChallenge(String? challenge) {
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

  /// A function that derives client and server keys using the `PBKDF2`
  /// algorithm with a given `password`, `salt`, `iterations`, and
  /// `hash function`.
  /// * @param password The password to use for key derivation.
  /// * @param iterations The number of iterations to use for key derivation.
  /// * @param hashBits The length of the hash function output, in bits.
  /// * @param hashName The name of the hash function to use for key derivation.
  /// * @param salt The salt to use for key derivation.
  ///
  /// * @return A map containing the derived client and server keys, encoded as
  /// [Uint8List]s.
  Map<String, Uint8List> deriveKeys({
    required String password,
    required int iterations,
    required int hashBits,
    required String hashName,
    required Uint8List salt,
  }) {
    final hash = _getDigest(hashName);

    /// Convert the password string to a byte array.
    final passwordBytes = Utils.stringToArrayBuffer(password);

    /// Create PBKDF2 parameters and key derivation function
    final pbkdf2Params = Pbkdf2Parameters(salt, iterations, hashBits ~/ 8);
    final pbkdf2 = PBKDF2KeyDerivator(HMac.withDigest(hash))
      ..init(pbkdf2Params);

    /// Derive key using PBKDF2 algorithm
    final keyBytes = pbkdf2.process(Uint8List.fromList(passwordBytes));

    /// Sign the derived keys using the HMAC algorithm
    return <String, Uint8List>{
      'ck': _sign(HMac(hash, keyBytes.length), 'Client Key'),
      'sk': _sign(HMac(hash, keyBytes.length), 'Server Key'),
    };
  }

  /// Determine the hash function to use based on the provided `hashName`
  /// parameter.
  static Digest _getDigest(String hashName) {
    /// If the `hashName` is not supported, then throw an [ArgumentError].
    switch (hashName) {
      case 'SHA-1':
        return SHA1Digest();
      case 'SHA-256':
        return SHA256Digest();
      case 'SHA-384':
        return SHA384Digest();
      case 'SHA-512':
        return SHA512Digest();
      case 'SHA3-256':
        return SHA3Digest(256);
      case 'SHA3-512':
        return SHA3Digest(512);
      default:
        throw ArgumentError('Invalid hash algorithm: $hashName');
    }
  }

  /// A helper function that signs a given string using the HMAC algorithm with
  /// a given hash function and key length.
  /// * @param hmac The HMAC object to use for signing.
  /// * @param data The string to sign.
  /// * @return The signed data, encoded as a Uint8List.
  static Uint8List _sign(HMac hmac, String data) =>
      hmac.process(Utils.stringToArrayBuffer(data));

  /// The purpose ofthis method is to sign the given `message` using the
  /// `serverKey` and the specified `hashName` algorithm. It returns the signed
  /// message as a [Uint8List].
  Uint8List serverSign(String message, Uint8List serverKey, String hashName) {
    /// Initialize [Digest] beforehand.
    Digest hash;

    /// If the `hashName` parameter is not one of the supported algorithms
    /// (`SHA-256`, `SHA-1` or `SHA-512`), it will throw an [ArgumentError].
    if (hashName == 'SHA-256') {
      hash = SHA256Digest();
    } else if (hashName == 'SHA-1') {
      hash = SHA1Digest();
    } else if (hashName == 'SHA-512') {
      hash = SHA512Digest();
    } else {
      throw ArgumentError(
        'Provided hashing algorithm is not supported: $hashName',
      );
    }

    /// The `serverKey` is used to initialize an HMAC (Hash-based Message
    /// Authentication Code) instance with the specified hash algorithm, and
    /// then `auth` is processed using this HMAC instance to generate the signed
    /// message.
    final hmac = HMac(hash, serverKey.length * 8);

    /// Initialize created `hmac`.
    hmac.init(KeyParameter(serverKey));

    /// The signed message is then returns as [Uint8List].
    return _sign(hmac, message);
  }

  /// This method generates a client nonce, which is used as part of the SCRAM
  /// authentication protocol. It generates 16 random bytes, encodes them them
  /// in base64, and removes any commas from the resulting string.
  /// * @return A [String] representing the generated client nonce.
  static String get generateCNonce {
    /// Generate 16 random bytes of nonce.
    final bytes = Uint8List(16);
    final random = math.Random.secure();
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }

    /// Base64-encode the nonce
    final base64Nonce = Utils.arrayBufferToBase64(bytes);

    /// Remove ',' character.
    return base64Nonce.replaceAll(',', '');
  }

  /// Returns a string containing the client first message.
  ///
  /// The message includes the client's authentication identity, a random nonce
  /// to be used in the authentication process, and other information about the
  /// authentication exchange.
  ///
  /// The `connection` parameter is an object containing the connection details,
  /// including the authentication identity to be used (`connection.authcid`).
  ///
  /// The `clientChallenge` method updates the `connection._sasl_data` object
  /// with information about the authentication process, including the client
  /// nonce (`cnonce`) and the client first message (`client-first-message-bare`).
  ///
  static String clientChallenge(Echo connection, String? testCNonce) {
    /// The optional `test_cnonce` parameter is a string value that can be used
    /// for testing purposes instead of generating a random nonce. If it is not
    /// provided, a random nonce will be generated.
    ///
    final cnonce = testCNonce ?? generateCNonce;
    final clientFirstMessageBare = 'n=${connection.authcid},r=$cnonce';
    connection.saslData!['cnonce'] = cnonce;
    connection.saslData!['client-first-message-bare'] = clientFirstMessageBare;

    /// The method returns a string value containing the client first message in
    /// the following format: "n,,n=<authentication identity>,r=<nonce>".
    return 'n,,$clientFirstMessageBare';
  }

  /// Performs SCRAM authentication and generates a response string to be sent
  /// to the server.
  ///
  /// * @param connection An instance of [Echo] representing the
  /// connection to the server.
  /// * @param challenge A string representing the challenge received from the
  /// server
  /// * @param hashName A string representing the name of the hash function to
  /// be used in the HMAC operation.
  /// * @param hashBits An integer representing the number of bits of the hash
  /// function.
  /// * @return A string representing the SCRAM response to be sent to the
  /// server.
  String? scramResponse(
    Echo connection,
    String challenge,
    String hashName,
    int hashBits,
  ) {
    /// Check if the `cnonce` key is present in `saslData` object of
    /// `connection`.
    final cnonce = connection.saslData!['cnonce'] as String;

    /// Parse the received challenge string.
    final challengeData = parseChallenge(challenge);

    /// Check if the challenge is valid by verifying the nonce.
    ///
    /// The RFC requires that we verify the (server) nonce has the client nonce
    /// as an initial substring.
    if (challengeData == null ||
        (challengeData['nonce'] as String).substring(0, cnonce.length) !=
            cnonce) {
      Log().warn(
        'Failing SCRAM authentication because server supplied incorrect nonce.',
      );
      connection.saslData = {};

      /// TODO: add return _sasl.failure.cb() in return type;
      return null;
    }

    Uint8List? clientKey;
    Uint8List? serverKey;

    /// Check if the password matches with the challenge.
    if (connection.password!['name'] == hashName &&
        connection.password!['salt'] ==
            Utils.arrayBufferToBase64(challengeData['salt'] as Uint8List) &&
        connection.password!['iteration'] == challengeData['iteration']) {
      clientKey =
          Utils.base64ToArrayBuffer(connection.password!['ck'] as String);
      serverKey =
          Utils.base64ToArrayBuffer(connection.password!['sk'] as String);
    }

    /// If not, derive keys using the provided password.
    else if (connection.password is String) {
      final keys = deriveKeys(
        password: connection.password!['password'] as String,
        iterations: challengeData['iteration'] as int,
        hashBits: hashBits,
        hashName: hashName,
        salt: challengeData['salt'] as Uint8List,
      );
      clientKey = keys['ck'];
      clientKey = keys['sk'];
    } else {
      return null;
    }

    final clientFirstMessageBare =
        connection.saslData!['client-first-message-bare'];
    final serverFirstMessage = challenge;
    final clientFinalMessageBare = 'c=biws,r=${challengeData['nonce']}';

    final message =
        '$clientFirstMessageBare,$serverFirstMessage,$clientFinalMessageBare';

    final proof = clientProof(message, hashName, clientKey!);
    final serverSignature = serverSign(message, serverKey!, hashName);

    connection.saslData!['server-signature'] =
        Utils.arrayBufferToBase64(serverSignature);
    connection.saslData!['keys'] = {
      'name': hashName,
      'iter': challengeData['iter'],
      'salt': Utils.arrayBufferToBase64(
        challengeData['salt'] as Uint8List,
      ),
      'ck': Utils.arrayBufferToBase64(clientKey),
      'sk': Utils.arrayBufferToBase64(serverKey),
    };

    return '$clientFinalMessageBare,p=${Utils.arrayBufferToBase64(proof)}';
  }
}
