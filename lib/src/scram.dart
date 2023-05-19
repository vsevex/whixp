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
  static Uint8List clientProof(
    /// The message to be signed by the client
    String message,

    /// The name of the hash function to be used in the HMAC operation
    String hashName,

    /// The key to be used in the HMAC operation
    Uint8List clientKey,
  ) {
    final storedKey = convert.hex.encode(clientKey);
    final signature = _hmacSha1(storedKey, message);

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
  /// * @return A map containing the derived client and server keys, encoded as
  /// [Uint8List]s.
  Map<String, Uint8List> deriveKeys({
    required String password,
    required String hashName,
    required Uint8List salt,
    required int iterations,
    required int hashBits,
  }) {
    final hash = _getDigest(hashName);

    /// Derive key using PBKDF2 algorithm.
    ///
    /// Convert the password string to a byte array.
    final saltedPasswordBites =
        hmacIteration(key: password, salt: salt, iterations: iterations);

    /// Sign the derived keys using the HMAC algorithm
    return <String, Uint8List>{
      'ck': _hmacSha1(
        convert.hex.encode(saltedPasswordBites),
        'Client Key',
        hash,
      ),
      'sk': _hmacSha1(
        convert.hex.encode(saltedPasswordBites),
        'Server Key',
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
  /// * @return The derived cryptographic key as Uint8List.
  static Uint8List hmacIteration({
    required String key,
    required Uint8List salt,
    required int iterations,

    /// Default to `SHA-1` hash.
    String hashName = 'SHA-1',

    /// Defaults to 1.
    int blockNr = 1,
  }) {
    /// Convert the block number to a [ByteData] object.
    final blockNrBytes = _packIntToBytes(blockNr);

    /// Create a Uint8List by concatenating the salt and block number bytes.
    final dataWithBlock =
        Uint8List.fromList([...salt, ...blockNrBytes.buffer.asUint8List()]);

    /// Generate the initial key material.
    Uint8List u = _sign(
      crypto.Hmac(_getDigest(hashName), Utils.stringToArrayBuffer(key)),
      dataWithBlock,
    );
    final res = u;
    int i = 1;

    /// Perform the remaining iterations.
    while (i < iterations) {
      /// Generate the next key material using HMAC.
      u = _sign(
        crypto.Hmac(_getDigest(hashName), Utils.stringToArrayBuffer(key)),
        u,
      );
      for (int j = 0; j < res.length; j++) {
        res[j] = res[j] ^ u[j];
      }
      i += 1;
    }
    return res;
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

  /// A helper function that signs a given string using the HMAC algorithm with
  /// a given hash function and key length.
  /// * @param hmac The Hmac object to use for signing.
  /// * @param data The string to sign.
  /// * @return The signed data, encoded as a Uint8List.
  static Uint8List _sign(crypto.Hmac hmac, Uint8List data) {
    final digest = hmac.convert(data);

    return Uint8List.fromList(convert.hex.decode(digest.toString()));
  }

  static Uint8List _hmacSha1(
    String key,
    String data, [
    crypto.Hash hash = crypto.sha1,
  ]) {
    final digest =
        crypto.Hmac(hash, utf8.encode(key)).convert(utf8.encode(data));
    return Uint8List.fromList(digest.bytes);
  }

  /// The purpose ofthis method is to sign the given `message` using the
  /// `serverKey` and the specified `hashName` algorithm. It returns the signed
  /// message as a [Uint8List].
  Uint8List serverSign(String message, Uint8List serverKey, String hashName) {
    /// Initialize [Digest] beforehand.
    final hash = _getDigest(hashName);

    /// The `key` is used to initialize an HMAC (Hash-based Message
    /// Authentication Code) instance with the specified hash algorithm, and
    /// then `auth` is processed using this HMAC instance to generate the signed
    /// message.
    final key = convert.hex.encode(serverKey);

    /// The signed message is then returns as [Uint8List].
    return _hmacSha1(key, message, hash);
  }

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

    Uint8List? clientKey;
    Uint8List? serverKey;

    if (connection._password is Map) {
      final password = connection._password as Map<String, dynamic>;

      /// Check if the password matches with the challenge.
      if (password['name'] == hashName &&
          password['salt'] ==
              Utils.arrayBufferToBase64(challengeData['salt'] as Uint8List) &&
          password['iter'] == challengeData['iteration']) {
        clientKey = Utils.base64ToArrayBuffer(password['ck'] as String);
        serverKey = Utils.base64ToArrayBuffer(password['sk'] as String);
      }
    } else if (connection._password is String) {
      final password = connection._password as String?;

      /// If not, derive keys using the provided password.
      if (password != null) {
        final keys = deriveKeys(
          password: password,
          iterations: challengeData['iter'] as int,
          hashBits: hashBits,
          hashName: hashName,
          salt: challengeData['salt'] as Uint8List,
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

    final proof = clientProof(message, hashName, clientKey!);
    final serverSignature = serverSign(message, serverKey!, hashName);

    connection._saslData!['server-signature'] = base64.encode(serverSignature);
    connection._saslData!['keys'] = {
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
