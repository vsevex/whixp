/// Serves as the foundation for establishing and managing XMPP (Extensible
/// Messaging and Presence Protocol) connections.
library whixp;

export 'src/exception.dart';
export 'src/jid/jid.dart';
export 'src/log/log.dart';
export 'src/plugins/plugins.dart';
export 'src/roster/manager.dart';
export 'src/stanza/atom.dart';
export 'src/stanza/error.dart';
export 'src/stanza/iq.dart';
export 'src/stanza/message.dart';
export 'src/stanza/presence.dart';
export 'src/stanza/roster.dart' hide RosterItem;
export 'src/utils/utils.dart';
export 'src/whixp.dart';
