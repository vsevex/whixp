import 'package:echox/src/jid/jid.dart';
import 'package:echox/src/stream/base.dart';
import 'package:echox/src/stream/matcher/base.dart';

/// Selects stanzas that have the same stanza 'id' interface value as the
/// desired ID.
class MatcherID extends BaseMatcher {
  MatcherID(super.criteria);

  @override
  bool match(XMLBase base) => base['id'] == criteria as String;
}

/// The IDSender matcher selects stanzas that have the same stanza 'id'
/// interface value as the desired ID, and that the 'from' value is one of a
/// set of approved entities that can respond to a request.
class MatchIDSender extends BaseMatcher {
  MatchIDSender(super.criteria) : assert(criteria.runtimeType is CriteriaType);

  /// Compare the given stanza's `id` attribute to the stored `id` value, and
  /// verify the sender's JID.
  @override
  bool match(XMLBase base) {
    final selfJID = (criteria as CriteriaType).self;
    final peerJID = (criteria as CriteriaType).peer;

    late final allowed = <String, bool>{};
    allowed[''] = true;
    allowed[selfJID.bare] = true;
    allowed[selfJID.domain] = true;
    allowed[peerJID.full] = true;
    allowed[peerJID.bare] = true;
    allowed[peerJID.domain] = true;

    final from = base['from'];

    try {
      return base['id'] == (criteria as CriteriaType).id && allowed[from]!;
    } catch (_) {
      return false;
    }
  }
}

class CriteriaType {
  const CriteriaType(this.self, this.peer, this.id);

  final JabberID self;
  final JabberID peer;
  final String id;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CriteriaType &&
          runtimeType == other.runtimeType &&
          self == other.self &&
          peer == other.peer &&
          id == other.id;

  @override
  int get hashCode => self.hashCode ^ peer.hashCode ^ id.hashCode;
}
