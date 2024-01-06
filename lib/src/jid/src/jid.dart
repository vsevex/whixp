import 'dart:io';

import 'package:dartz/dartz.dart';

import 'package:memoize/memoize.dart';

import 'package:whixp/src/escaper/escaper.dart';
import 'package:whixp/src/jid/src/exception.dart';
import 'package:whixp/src/utils/src/stringprep.dart';

/// A private utility class for parsing, formatting, and validating Jabber IDs.
class _Jabbered {
  const _Jabbered();

  /// Regular expression pattern for parsing Jabber IDs.
  static final pattern = RegExp(
    r"""^(?:([^\"&'/:<>@]{1,1023})@)?([^/@]{1,1023})(?:/(.{1,1023}))?$""",
  );

  /// Parses a Jabber ID string into its components (node, domain, resource).
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

  /// Formats a Jabber ID using the provided components (node, domain,
  /// resource).
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

  /// Validate the local, or username, portion of a JID.
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

  /// Validate the domain portion of a JabberID. If the given domain is
  /// actually a punycoded version of a domain name, it is converted back into
  /// its original Unicode form. Domains must also not start or end with a
  /// dash.
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

  /// Validate the resource portion of a JID.
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

/// A representation of a Jabber ID, or JID.
///
/// Each JID may have three components: a node, a domain, and an optional
/// resource. For example: vsevex@example.com/resource
///
/// When a resource is not used, the JID is called a bare JID. The JID is a
/// full JID otherwise.
class JabberID {
  /// Constructs a JabberID instance from a JID String.
  JabberID([String? jid]) {
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

  /// Updates the bare and full JID strings based on the current components.
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

  /// Unescapes the full JID string using the [Escaper] utility.
  String get unescaped => Escaper().unescape(full);

  /// Formats the Jabber ID into a string.
  String get formatted => _Jabbered._format();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JabberID &&
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

  /// Use the full JID as  the string value.
  @override
  String toString() => _full;
}
