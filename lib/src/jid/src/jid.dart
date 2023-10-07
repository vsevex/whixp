import 'dart:io';

import 'package:dartz/dartz.dart';

import 'package:echox/src/echotils/src/stringprep.dart';
import 'package:echox/src/escaper/escaper.dart';
import 'package:echox/src/jid/src/exception.dart';

import 'package:memoize/memoize.dart';

part '_escape.dart';

class _Jabbered {
  const _Jabbered();

  static final pattern = RegExp(
    r"""^(?:([^\"&'/:<>@]{1,1023})@)?([^/@]{1,1023})(?:/(.{1,1023}))?$""",
  );

  static Tuple3<String, String, String> _parse(String jid) {
    final match = memo0<RegExpMatch?>(() => pattern.firstMatch(jid)).call();

    if (match == null) {
      throw JabberIDException.invalid();
    }

    final node = _validateNode(match.group(1));
    final domain = _validateDomain(match.group(2));
    final resource = _validateResource(match.group(3));

    return Tuple3(node, domain, resource);
  }

  static String _format({String? node, String? domain, String? resource}) {
    late String result;
    if (domain == null) {
      return '';
    }

    if (node != null) {
      result = '$node@$domain';
    } else {
      result = domain;
    }

    if (resource != null) {
      result += '/$resource';
    }

    return result;
  }

  static String _validateNode(String? regex) {
    if (regex == null) {
      return '';
    }

    late String node = regex;

    try {
      node = StringPreparationProfiles().nodePrep(node);
    } on Exception {
      throw JabberIDException.nodeprep();
    }

    if (node.isEmpty) {
      throw JabberIDException('Localpart must not be 0 bytes');
    }
    if (node.length > 1023) {
      throw JabberIDException.length('Localpart');
    }

    return node;
  }

  static String _validateDomain(String? regex) {
    bool ipAddress = false;

    if (regex == null) {
      return '';
    }

    String domain = regex;

    try {
      InternetAddress(domain, type: InternetAddressType.IPv4);
      ipAddress = true;
    } catch (_) {
      /// Not an IPv4 address
    }

    if (!ipAddress && domain.startsWith('[') && domain.endsWith(']')) {
      try {
        InternetAddress(
          domain.substring(1, domain.length - 1),
          type: InternetAddressType.IPv6,
        );
        ipAddress = true;
      } catch (_) {
        /// Not an IPv6 address
      }
    }

    if (!ipAddress) {
      /// This is a domain name, which must be checked further

      if (domain.isNotEmpty && domain.endsWith('.')) {
        domain = domain.substring(0, domain.length - 1);
      }

      try {
        domain = Uri.decodeComponent(domain);
      } on Exception {
        throw JabberIDException.idnaValidation(domain);
      }

      if (domain.contains(':')) {
        throw JabberIDException('Domain containing a port: $domain');
      }

      for (final label in domain.split('.')) {
        if (label.isEmpty) {
          throw JabberIDException('Domain containing too many dots: $domain');
        }
        if (label.startsWith('-') || label.endsWith('-')) {
          throw JabberIDException('Domain starting or ending with -: $domain');
        }
      }
    }

    if (domain.isEmpty) {
      throw JabberIDException('Domain must not be 0 bytes');
    }

    if (domain.length > 1023) {
      throw JabberIDException.length('Domain');
    }

    return domain;
  }

  static String _validateResource(String? regex) {
    if (regex == null) {
      return '';
    }

    late String resource = regex;

    try {
      resource = StringPreparationProfiles().resourcePrep(resource);
    } on Exception {
      throw JabberIDException.resourceprep();
    }

    if (resource.isEmpty) {
      throw JabberIDException('Resource must not be 0 bytes');
    }

    if (resource.length > 1023) {
      throw JabberIDException.length('Resource');
    }

    return resource;
  }
}

class JabberIDTemp {
  JabberIDTemp({String? jid}) {
    if (jid == null) return;
    final jabberID = _Jabbered._parse(jid);
    _node = jabberID.value1;
    _domain = jabberID.value2;
    _resource = jabberID.value3;
    _bare = '';
    _full = '';

    _updateBareFull();
  }

  late String _node;
  late String _domain;
  late String _resource;
  late String _bare;
  late String _full;

  void _updateBareFull() {
    _bare = _node.isNotEmpty ? '$_node@$_domain' : _domain;
    _full = _resource.isNotEmpty ? '$_bare/$_resource' : _bare;
  }

  String get bare => _bare;

  String get node => _node;

  String get domain => _domain;

  String get resource => _resource;

  String get full => _full;
  String get user => _node;
  set user(String user) => node = user;
  String get local => _node;
  set local(String user) => node = user;
  String get username => _node;
  set username(String user) => node = user;
  String get server => _domain;
  set server(String user) => domain = user;
  String get host => _domain;
  set host(String user) => domain = user;
  String get jid => _full;
  set jid(String user) => full = user;

  set bare(String bare) {
    final jid = _Jabbered._parse(bare);
    assert(jid.value2.isNotEmpty);
    _node = jid.value1;
    _domain = jid.value2;
    _updateBareFull();
  }

  set node(String node) {
    _node = _Jabbered._validateNode(node);
    _updateBareFull();
  }

  set domain(String domain) {
    _domain = _Jabbered._validateDomain(domain);
    _updateBareFull();
  }

  set resource(String resource) {
    _resource = _Jabbered._validateResource(resource);
    _updateBareFull();
  }

  set full(String value) {
    final jid = _Jabbered._parse(value);
    _node = jid.value1;
    _domain = jid.value2;
    _resource = jid.value3;
    _updateBareFull();
  }

  String get unescaped => Escaper().unescape(full);

  String get formatted => _Jabbered._format();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JabberIDTemp &&
          runtimeType == other.runtimeType &&
          node == other.node &&
          domain == other.domain &&
          resource == other.resource &&
          _bare == other._bare &&
          _full == other._full;

  @override
  int get hashCode =>
      node.hashCode ^
      domain.hashCode ^
      resource.hashCode ^
      _bare.hashCode ^
      _full.hashCode;

  @override
  String toString() => _full;
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
