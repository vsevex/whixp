import 'package:dartz/dartz.dart';
import 'package:echox/src/escaper/escaper.dart';
import 'package:echox/src/jid/src/exception.dart';
import 'package:echox/src/stringprep/stringprep.dart';

part '_escape.dart';

class JabberIDTemp {
  final pattern = RegExp(
    r"""^(?:([^\"&'/:<>@]{1,1023})@)?([^/@]{1,1023})(?:/(.{1,1023}))?$""",
  );

  Tuple3<String, String, String> _parse(String jid) {
    final matches = pattern.allMatches(jid).toList();

    final node = _validateNode(matches[0]);
    final domain = matches[1];
    final resource = matches[2];

    return Tuple3(node, domain, resource);
  }

  String _validateNode(RegExpMatch? node) {
    if (node == null) {
      return '';
    }

    try {
      final 
    }
  }
}

/// Represents a Jabber ID, which consists of a local part, a domain part, and
/// an optional resource part. Provides methods to manipulate Jabber IDs and
/// manage their components.
class JabberID {
  /// Creates a new instance of the [JabberID] class.
  JabberID(this.local, {this.domain, this.resource}) {
    setDomain(domain);
    setLocal(local);
  }

  /// The local part of the Jabber ID. This is the part that comes before the
  /// `@` symbol.
  String local;

  /// The domain part of the Jabber ID. This is the part that comes after the
  /// local part and `@` sign.
  String? domain;

  /// The resource part of the Jabber ID. This is the part that comes after the
  /// domain name.
  String? resource;

  /// Creates a new instance of the [JabberID] class from a string
  /// representation.
  ///
  /// The [jid] parameter is a string in the format "local@domain/resource". If
  /// no resource part is provided, the format is "local@domain".
  ///
  /// ### Example:
  /// ```dart
  /// final jid = JabberID.fromString('local@domain/mobile');
  ///
  /// log(jid.local); /// outputs "local"
  /// ```
  factory JabberID.fromString(String jid) {
    final parts = jid.split('/');

    /// The local part of the Jabber ID. This is the part that comes before the
    /// `@` symbol.
    late String local;

    /// The domain part of the Jabber ID. This is the part that comes after the
    ///  local part and `@` sign.
    String domain;

    /// The resource part of the Jabber ID. This is the part that comes after the
    /// domain name.
    String? resource;

    if (!jid.contains('@')) {
      return JabberID(jid);
    }

    if (parts.length > 1) {
      local = parts[0].split('@').first;
      domain = parts[0].split('@')[1];
      resource = parts[1];
    } else {
      final parts = jid.split('@');
      local = parts.first;
      domain = parts[1];
    }

    return JabberID(local, domain: domain, resource: resource);
  }

  /// Returns the bare Jabber ID, removing the resource part if present.
  ///
  /// ### Example:
  /// ```dart
  /// final jid = JabberID('local', domain: 'domain', resource: 'mobile');
  /// log(jid.bare); /// outputs bare JID as "local@domain"
  /// ```
  JabberID get bare {
    if (resource != null) {
      return JabberID(local, domain: domain);
    }

    return this;
  }

  /// Sets the local part of the Jabber ID. Escapes the local part if necessary.
  ///
  /// ### Example:
  /// ```dart
  /// final jid = JabberID('local', domain: 'domain');
  /// jid.setLocal('hert');
  /// log(jid.local); /// outputs "hert"
  /// ```
  void setLocal(String local) {
    final escaped = _detect(local);

    if (escaped) {
      this.local = Escaper().escape(local);
    } else {
      this.local = local.toLowerCase();
    }
  }

  /// Returns the local part of the Jabber ID.
  ///
  /// The [unescape] parameter determines whether to unescape the local part.
  String getLocal({bool unescape = false}) {
    final local = unescape ? Escaper().unescape(this.local) : this.local;

    return local;
  }

  /// Sets the domain part of the Jabber ID.
  void setDomain(String? domain) => this.domain = domain?.toLowerCase();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JabberID &&
          runtimeType == other.runtimeType &&
          local == other.local &&
          domain == other.domain &&
          resource == other.resource;

  @override
  int get hashCode => local.hashCode ^ domain.hashCode ^ resource.hashCode;

  @override
  String toString({bool unescape = false}) {
    late final string = StringBuffer();

    if (domain == null) {
      return local;
    }

    string
      ..write(getLocal(unescape: unescape))
      ..write('@')
      ..write(domain);

    if (resource != null) {
      string
        ..write('/')
        ..write(resource);
    }

    return string.toString();
  }
}
