import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;

import 'package:whixp/src/exception.dart';
import 'package:whixp/src/utils/utils.dart';
import 'package:whixp/src/whixp.dart';

/// [Scram] is a class used for the SCRAM (Saited Challenge Response
/// Authentication Mechanism) authentication in the XMPP protocol.
class Scram {
  Scram(this.whixp);

  final WhixpBase whixp;

  /// This method is used to generate the proof of the client's identity to the
  /// server, which is required for the SCRAM authentication mechanism. Without
  /// this method, the authentication process cannot be completed successfully.
  static String clientProof(
    /// The message to be signed by the client
    String message,

    /// The key to be used in the HMAC operation
    String clientKey,

    /// The name of the hash function to be used in the HMAC operation
    String hashName,
  ) {
    /// Declare the hashing algorithm.
    final hash = _getDigest(hashName);
    final storedKey = hashShaConvert(clientKey, hash);
    final signature =
        hmacShaConvert(storedKey, Uint8List.fromList(message.codeUnits), hash);

    return WhixpUtils.xorUint8Lists(clientKey, signature);
  }

  /// The purpose ofthis method is to sign the given `message` using the
  /// `serverKey` and the specified `hashName` algorithm. It returns the signed
  /// message as a [Uint8List].
  String serverSign(String message, String serverKey, String hashName) {
    /// Initialize [Digest] beforehand.
    final hash = _getDigest(hashName);

    /// The signed message is then returns as [Uint8List].
    return hmacShaConvert(
      serverKey,
      Uint8List.fromList(message.codeUnits),
      hash,
    );
  }

  /// Parses SCRAM [challenge] [String] and returns a [Map] of three values,
  /// including the `nonce`, `salt`, and `iteration` count, if they exist
  /// in the [challenge] string. Otherwise, it returns `null` if any of these
  /// values is missing or invalid.
  static Map<String, dynamic> parseChallenge(String? challenge) {
    /// A [String] representing the server's `nonce` value.
    String? nonce;

    /// A [List] of integers representing `salt` value received from the server.
    List<int>? salt;

    /// An [int] representing the number of iterations to perform during key
    /// derivation.
    int? iter;

    /// If challenge is null, throw a SCRAM error.
    if (challenge == null || challenge.isEmpty) {
      throw SASLException.scram('The challenge from the server is empty');
    }

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

      if (matches[1] == 'r') {
        nonce = matches[2];
      } else if (matches[1] == 's') {
        salt = WhixpUtils.base64ToArrayBuffer(matches[2]!);
      } else if (matches[1] == 'i') {
        iter = int.parse(matches[2]!, radix: 10);
      } else {
        break;
      }
    }

    /// If the iteration count is less than 4096, throw an error.
    if (iter == null || iter < 4096) {
      throw SASLException.scram('Iteration is null or lesser than 4096');
    }

    /// If the salt value is not present, throw an error.
    if (salt == null) {
      throw SASLException.scram('Parsed salt from the challenge is null');
    }

    /// Return a Map containing the `nonce`, `salt`, and `iter` values.
    return {'nonce': nonce, 'salt': salt, 'iter': iter};
  }

  /// A function that derives client and server keys using the `PBKDF2`
  /// algorithm with a given `password`, `salt`, `iterations`, and
  /// `hash function`. Returns a map containing the derived client and server
  /// keys, as [String].
  Map<String, String> deriveKeys({
    /// The password to use for key derivation.
    required String password,

    /// The number of iterations to use for key derivation.
    required int iterations,

    /// The name of the hash function to use for key derivation.
    required String hashName,

    /// The salt to use for key derivation.
    required String salt,
  }) {
    final hash = _getDigest(hashName);

    /// Derive key using PBKDF2 algorithm.
    ///
    /// Convert the password string to a byte array.
    final saltedPasswordBites = hmacIteration(
      key: password,
      salt: salt,
      iterations: iterations,
      hashName: hashName,
    );

    /// Sign the derived keys using the HMAC algorithm
    return <String, String>{
      'ck': hmacShaConvert(
        saltedPasswordBites,
        WhixpUtils.stringToArrayBuffer('Client Key'),
        hash,
      ),
      'sk': hmacShaConvert(
        saltedPasswordBites,
        WhixpUtils.stringToArrayBuffer('Server Key'),
        hash,
      ),
    };
  }

  /// Performs an HMAC iteration operation using the provided parameters.
  ///
  /// This method applies the HMAC (Hash-based Message Authentication Code)
  /// iteration process to derive a cryptographic key from the given inputs. It
  /// uses a specific [key], [salt], number of [iterations], [hash] algorithm,
  /// and [blockNumber] to generate the resulting key material.
  static String hmacIteration({
    /// The key used for HMAC computation.
    required String key,

    /// The salt value used in the HMAC iteration.
    required String salt,

    /// The number of iterations to perform.
    required int iterations,

    /// The name of hash algorithm to use (defaults to 'SHA-1').
    String hashName = 'SHA-1',

    /// Defaults to 1.
    int blockNumber = 1,
  }) {
    /// Get the hashing algorithm
    final hash = _getDigest(hashName);

    /// Convert the block number to a [ByteData] object.
    final blockNrBytes = _packIntToBytes(blockNumber);

    /// Create a Uint8List by concatenating the salt and block number bytes.
    final dataWithBlock = Uint8List.fromList([
      ...salt.codeUnits,
      ...blockNrBytes.buffer.asUint8List(),
    ]);

    /// Generate the initial key material.
    Uint8List u =
        Uint8List.fromList(hmacShaConvert(key, dataWithBlock, hash).codeUnits);
    final res = u;
    int i = 1;

    /// Perform the remaining iterations.
    while (i < iterations) {
      /// Generate the next key material using HMAC.
      u = Uint8List.fromList(hmacShaConvert(key, u, hash).codeUnits);
      for (int j = 0; j < res.length; j++) {
        res[j] = res[j] ^ u[j];
      }
      i += 1;
    }
    return String.fromCharCodes(res);
  }

  /// Packs an integer value into a [ByteData] object.
  ///
  /// This method takes an integer [value] and converts it into a [ByteData]
  /// object with a length of 4 bytes.
  static ByteData _packIntToBytes(int value) {
    /// Set the value of the Uint32 at the beginning of the [ByteData] object.
    final list = ByteData.view(Uint8List(4).buffer)..setUint32(0, value);

    /// Return the [ByteData] object.
    return list;
  }

  /// Determine the hash function to use based on the provided `hashName`
  /// parameter.
  static crypto.Hash _getDigest(String hashName) {
    /// If the `hashName` is not supported, then throw an [SASLException].
    switch (hashName) {
      case 'SHA-1':
        return crypto.sha1;
      case 'SHA-256':
        return crypto.sha256;
      case 'SHA-384':
        return crypto.sha384;
      case 'SHA-512':
        return crypto.sha512;
      default:
        throw SASLException.unknownHash(hashName);
    }
  }

  /// Computes the SHA-1 [hash] of the input [data].
  static String hashShaConvert(String data, [crypto.Hash hash = crypto.sha1]) =>
      String.fromCharCodes(
        hash.convert(Uint8List.fromList(data.codeUnits)).bytes,
      );

  /// Computes the HMAC-SHA1 hash of the input data using the provided key.
  ///
  /// Takes an input string key and a Uint8List data, and computes the HMAC-SHA1
  /// hash of the data using the provided key. The key is expected to be in
  /// UTF-8 encoding, while the data is expected to be a Uint8List representing
  /// binary data.
  static String hmacShaConvert(
    String key,
    Uint8List data, [
    crypto.Hash hash = crypto.sha1,
  ]) =>
      String.fromCharCodes(
        crypto.Hmac(hash, key.codeUnits).convert(data).bytes,
      );

  /// Generates a client nonce, which is used as part of the SCRAM
  /// authentication protocol. It generates 16 random bytes, encodes them them
  /// in base64, and removes any commas from the resulting string.
  static String get generateCNonce {
    /// Generate 16 random bytes of nonce.
    final bytes = List<int>.generate(16, (index) => math.Random().nextInt(256));

    /// Base64-encode the nonce
    return WhixpUtils.arrayBufferToBase64(Uint8List.fromList(bytes));
  }

  /// Returns a string containing the client first message.
  ///
  /// The message includes the client's authentication identity, a random nonce
  /// to be used in the authentication process, and other information about the
  /// authentication exchange.
  ///
  /// Updates the `whixp.saslData` variable with information about the
  /// authentication process, including the client nonce (`cnonce`) and the
  /// client first message (`clientFirstMessageBare`).
  String clientChallenge() {
    /// A random nonce will be generated.
    final cnonce = generateCNonce;

    final clientFirstMessageBare =
        'n=${whixp.credentials['username']},r=$cnonce';
    whixp.saslData['cnonce'] = cnonce;
    whixp.saslData['clientFirstMessageBare'] = clientFirstMessageBare;

    /// The method returns a string value containing the client first message in
    /// the following format: "n,,n=<authentication identity>,r=<nonce>".
    return 'n,,$clientFirstMessageBare';
  }

  /// Generates a SCRAM (Salted Challenge Response Authentication Mechanism)
  /// response string.
  ///
  /// - [challenge]
  /// - [hashName]
  /// - [hashBits]
  ///
  /// Returns a SCRAM response string or `null` if authentication fails.
  ///
  /// The method performs the following steps:
  /// 1. Checks if the 'cnonce' key is present in the 'saslData' object of the connection.
  /// 2. Parses the received challenge string.
  /// 3. Verifies the challenge's validity by comparing nonces.
  /// 4. Derives client and server keys using the user's password.
  /// 5. Computes the client proof and server signature.
  /// 6. Updates the 'saslData' object with relevant information.
  ///
  /// ### Example:
  /// ```dart
  /// final client = Whixp();
  /// final challenge = 'challengeString';
  /// final hashName = 'SHA-256';
  /// final hashBits = 256;
  /// final response = Scram(client).scramResponse(challenge, hashName, hashBits);
  /// ```
  ///
  /// See also:
  ///
  /// - [parseChallenge], a method used to parse the received challenge string.
  /// - [deriveKeys], a method used to derive client and server keys.
  /// - [clientProof], a method used to compute the client proof.
  /// - [serverSign], a method used to compute the server signature.
  ///
  String scramResponse(
    /// A string representing the challenge received from the server.
    String? challenge,

    /// A string representing the name of the hash function to be used in the
    /// HMAC operation.
    String hashName,

    /// An integer representing the number of bits of the hash function.
    int hashBits,
  ) {
    /// Check if the `cnonce` key is present in `saslData` object of
    /// `connection`.
    final cnonce = whixp.saslData['cnonce'] as String;

    /// Parse the received challenge string.
    final challengeData = parseChallenge(challenge);

    /// Check if the challenge is valid by verifying the nonce.
    ///
    /// The RFC requires that we verify the (server) nonce has the client nonce
    /// as an initial substring.
    if ((challengeData['nonce'] as String).substring(0, cnonce.length) !=
        cnonce) {
      whixp.saslData.clear();
      throw SASLException.cnonce();
    }

    String? clientKey;
    String? serverKey;

    final password = whixp.password;

    final keys = deriveKeys(
      password: password,
      iterations: challengeData['iter'] as int,
      hashName: hashName,
      salt: String.fromCharCodes(challengeData['salt'] as Uint8List),
    );
    clientKey = keys['ck'];
    serverKey = keys['sk'];

    final clientFirstMessageBare = whixp.saslData['clientFirstMessageBare'];
    final serverFirstMessage = challenge;
    final clientFinalMessageBare = 'c=biws,r=${challengeData['nonce']}';

    final message =
        '$clientFirstMessageBare,$serverFirstMessage,$clientFinalMessageBare';

    final proof = clientProof(message, clientKey!, hashName);
    final serverSignature = serverSign(message, serverKey!, hashName);

    whixp.saslData['server-signature'] = WhixpUtils.btoa(serverSignature);
    whixp.saslData['keys'] = {
      'name': hashName,
      'iter': challengeData['iter'],
      'salt': WhixpUtils.arrayBufferToBase64(
        challengeData['salt'] as Uint8List,
      ),
      'ck': WhixpUtils.btoa(clientKey),
      'sk': WhixpUtils.btoa(serverKey),
    };

    return '$clientFinalMessageBare,p=${WhixpUtils.btoa(proof)}';
  }
}
