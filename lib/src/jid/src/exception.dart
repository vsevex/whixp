import 'package:whixp/src/exception.dart';

/// Exception specific to Jabber ID (JID) operations, extending from
/// [WhixpException].
///
/// This exception class provides specific error messages for different
/// scenarios related to parsing, length validation, and preperation of Jabber
/// IDs.
class JabberIDException extends WhixpException {
  /// Constructs a [JabberIDException] with the given error message.
  JabberIDException(super.message);

  /// Factory constructor for creating a [JabberIDException] indicating a
  /// failed operation.
  factory JabberIDException.invalid() =>
      JabberIDException('JID could not be parsed');

  /// Factory constructor for creating [JabberIDException] indicating a length
  /// validation failure.
  factory JabberIDException.length(String type) =>
      JabberIDException('$type must be less than 1024 bytes');

  /// Indicates a failure in Nodeprep operation.
  factory JabberIDException.nodeprep() => JabberIDException('Nodeprep failed');

  /// Indicates a failure in Resourceprep operation.
  factory JabberIDException.resourceprep() =>
      JabberIDException('Resouceprep failed');

  /// Indicates a failure in IDNA validation.
  factory JabberIDException.idnaValidation(String domain) =>
      JabberIDException('idna validation failed: $domain');
}
