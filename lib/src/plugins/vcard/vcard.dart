import 'dart:async';

import 'package:whixp/src/exception.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/plugins/disco/disco.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/stream/matcher/matcher.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

part 'stanza.dart';

/// vCards are an existing and widely-used standard for personal user
/// information storage, somewhat like an electronic business card.
///
/// see <https://xmpp.org/extensions/xep-0054.html>
class VCardTemp extends PluginBase {
  VCardTemp()
      : super(
          'vcard-temp',
          description: 'XEP-0054: vCard-Temp',
          dependencies: <String>{'disco', 'time'},
        );

  @override
  void pluginInitialize() {
    _cache = <String, VCardTempStanza>{};

    base.transport.registerHandler(
      CallbackHandler(
        'VCardTemp',
        (iq) => _handleGetVCard(iq as IQ),
        matcher: StanzaPathMatcher('iq/vcard_temp'),
      ),
    );
  }

  late final Map<String, VCardTempStanza> _cache;

  /// Retrieves a vCard.
  ///
  /// [cache] indicates that method should only check cache for vCard.
  FutureOr<IQ> getVCard<T>(
    JabberID jid, {
    JabberID? iqFrom,
    bool cache = false,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    bool local = cache;

    if (base.isComponent) {
      if (jid.domain == base.transport.boundJID.domain) {
        local = true;
      }
    } else {
      if (jid == base.transport.boundJID) {
        local = true;
      }
    }

    if (local) {
      final vCard = _cache[jid.bare];
      final iq = base.makeIQGet();
      if (vCard != null) {
        iq.add(vCard);
      }
      return iq;
    }

    final iq = base.makeIQGet(iqTo: jid, iqFrom: iqFrom);
    iq.enable('vcard_temp');
    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Publishes a [vCard].
  FutureOr<IQ> publish<T>(
    VCardTempStanza vCard, {
    JabberID? jid,
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    if (jid != null) _cache[jid.bare] = vCard;

    final iq = base.makeIQSet(iqTo: jid, iqFrom: iqFrom);
    iq.add(vCard.element!.copy());

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  void _handleGetVCard(IQ iq) {
    final type = iq['type'];
    if (type == 'result') {
      _cache[iq.from.toString()] = iq['vcard_temp'] as VCardTempStanza;
      return;
    } else if (type == 'get' && base.isComponent) {
      final vcard = _cache[iq.to.bare];
      final reply = iq.replyIQ();
      reply.add(vcard);
      reply.sendIQ();
    } else if (type == 'set') {
      throw StanzaException.serviceUnavailable(iq);
    }
  }

  @override
  void sessionBind(String? jid) {
    final disco = base.getPluginInstance<ServiceDiscovery>('disco');
    if (disco != null) {
      disco.addFeature('vcard-temp');
    }
  }

  @override
  void pluginEnd() {
    base.transport.removeHandler('VCardTemp');
    final disco = base.getPluginInstance<ServiceDiscovery>(
      'disco',
      enableIfRegistered: false,
    );
    if (disco != null) {
      disco.removeFeature('vcard-temp');
    }
  }
}
