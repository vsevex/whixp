import 'package:echox/echox.dart';

class JabberIDException extends EchoException {
  JabberIDException(super.message);

  factory JabberIDException.invalid() =>
      JabberIDException('JID could not be parsed');
  factory JabberIDException.length(String type) =>
      JabberIDException('$type must be less than 1024 bytes');
  factory JabberIDException.nodeprep() => JabberIDException('Nodeprep failed');
  factory JabberIDException.resourceprep() =>
      JabberIDException('Resouceprep failed');
  factory JabberIDException.idnaValidation(String domain) =>
      JabberIDException('idna validation failed: $domain');
}
