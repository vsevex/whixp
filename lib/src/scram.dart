part of 'echo.dart';

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
    final signature = hmacShaConvert(
      storedKey,
      Uint8List.fromList(message.codeUnits),
      hash,
    );

    return Echotils.xorUint8Lists(clientKey, signature);
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

      /// TODO: migrate to wildcard pattern
      if (matches[1] == 'r') {
        nonce = matches[2];
      } else if (matches[1] == 's') {
        salt = Echotils.base64ToArrayBuffer(matches[2]!);
      } else if (matches[1] == 'i') {
        iter = int.parse(matches[2]!, radix: 10);
      } else {
        return null;
      }
    }

    /// If the iteration count is less than 4096, log a warning message and
    /// return `null`.
    if (iter == null || iter < 4096) {
      Log().warn(
        'Failing SCRAM authentication because server supplied iteration count < 4096.',
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
  /// * @return A map containing the derived client and server keys, as [String].
  Map<String, String> deriveKeys({
    required String password,
    required String hashName,
    required String salt,
    required int iterations,
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
        Uint8List.fromList(utf8.encode('Client Key')),
        hash,
      ),
      'sk': hmacShaConvert(
        saltedPasswordBites,
        Uint8List.fromList('Server Key'.codeUnits),
        hash,
      ),
    };
  }

  /// Performs an HMAC iteration operation using the provided parameters.
  ///
  /// This method applies the HMAC (Hash-based Message Authentication Code)
  /// iteration process to derive a cryptographic key from the given inputs. It
  /// uses a specific `key`, `salt`, `number of iterations`, `hash algorithm`,
  /// and `block number` to generate the resulting key material.
  ///
  /// * @param key The key used for HMAC computation.
  /// * @param salt The salt value used in the HMAC iteration.
  /// * @param iterations The number of iterations to perform.
  /// * @param hashName The name of hash algorithm to use (defaults to 'SHA-1').
  /// * @param blockNr The block number used in the HMAC iteration (defaults to
  /// 1).
  /// * @return The derived cryptographic key as String.
  static String hmacIteration({
    required String key,
    required String salt,
    required int iterations,

    /// Default to `SHA-1` hash.
    String hashName = 'SHA-1',

    /// Defaults to 1.
    int blockNr = 1,
  }) {
    /// Get the hashing algorithm
    final hash = _getDigest(hashName);

    /// Convert the block number to a [ByteData] object.
    final blockNrBytes = _packIntToBytes(blockNr);

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
  /// This method takes an integer value and converts it into a [ByteData]
  /// object with a length of 4 bytes.
  ///
  /// * @param value The [int] value to be packed into the [ByteData] object.
  /// * @return The [ByteData] object containing the packed integer value.
  static ByteData _packIntToBytes(int value) {
    /// Set the value of the Uint32 at the beginning of the [ByteData] object.
    final list = ByteData.view(Uint8List(4).buffer)..setUint32(0, value);

    /// Return the [ByteData] object.
    return list;
  }

  /// Determine the hash function to use based on the provided `hashName`
  /// parameter.
  static crypto.Hash _getDigest(String hashName) {
    /// If the `hashName` is not supported, then throw an [ArgumentError].
    switch (hashName) {
      case 'SHA-1':
        return crypto.sha1;
      case 'SHA-256':
        return crypto.sha256;
      case 'SHA-384':
        return crypto.sha384;
      case 'SHA-512':
        return crypto.sha512;
      case 'SHA3-256':
        return crypto.sha512256;
      default:
        throw ArgumentError('Invalid hash algorithm: $hashName');
    }
  }

  /// Computes the SHA-1 hash of the input string.
  /// * @param data The input string to compute the SHA-1 hash for.
  /// * @return The SHA-1 hash of the input string, encoded as a hexadecimal
  /// string.
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

  /// This method generates a client nonce, which is used as part of the SCRAM
  /// authentication protocol. It generates 16 random bytes, encodes them them
  /// in base64, and removes any commas from the resulting string.
  /// * @return A [String] representing the generated client nonce.
  static String get generateCNonce {
    /// Generate 16 random bytes of nonce.
    final bytes = List<int>.generate(16, (index) => math.Random().nextInt(256));

    /// Base64-encode the nonce
    return base64.encode(bytes);
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
    final cnonce = testCNonce ?? generateCNonce;
    final clientFirstMessageBare = 'n=${connection._authcid},r=$cnonce';
    connection._saslData!['cnonce'] = cnonce;
    connection._saslData!['client-first-message-bare'] = clientFirstMessageBare;

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
    String? challenge,
    String hashName,
    int hashBits,
  ) {
    /// Check if the `cnonce` key is present in `saslData` object of
    /// `connection`.
    final cnonce = connection._saslData!['cnonce'] as String;

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
      connection._saslData = {};
      connection._saslFailureCB();
      return null;
    }

    String? clientKey;
    String? serverKey;

    if (connection._password is Map) {
      final password = connection._password as Map<String, dynamic>;

      /// Check if the password matches with the challenge.
      if (password['name'] == hashName &&
          password['salt'] ==
              Echotils.arrayBufferToBase64(
                challengeData['salt'] as Uint8List,
              ) &&
          password['iter'] == challengeData['iteration']) {
        clientKey = Echotils.atob(password['ck'] as String);
        serverKey = Echotils.atob(password['sk'] as String);
      }
    } else if (connection._password is String) {
      final password = connection._password as String?;

      /// If not, derive keys using the provided password.
      if (password != null) {
        final keys = deriveKeys(
          password: password,
          iterations: challengeData['iter'] as int,
          hashName: hashName,
          salt: String.fromCharCodes(challengeData['salt'] as Uint8List),
        );
        clientKey = keys['ck'];
        serverKey = keys['sk'];
      } else {
        connection._saslFailureCB();
        return null;
      }
    }

    final clientFirstMessageBare =
        connection._saslData!['client-first-message-bare'];
    final serverFirstMessage = challenge;
    final clientFinalMessageBare = 'c=biws,r=${challengeData['nonce']}';

    final message =
        '$clientFirstMessageBare,$serverFirstMessage,$clientFinalMessageBare';

    final proof = clientProof(message, clientKey!, hashName);
    final serverSignature = serverSign(message, serverKey!, hashName);

    connection._saslData!['server-signature'] = Echotils.btoa(serverSignature);
    connection._saslData!['keys'] = {
      'name': hashName,
      'iter': challengeData['iter'],
      'salt': Echotils.arrayBufferToBase64(
        challengeData['salt'] as Uint8List,
      ),
      'ck': Echotils.btoa(clientKey),
      'sk': Echotils.btoa(serverKey),
    };

    return '$clientFinalMessageBare,p=${Echotils.btoa(proof)}';
  }
}
