import 'package:dartz/dartz.dart';
import 'package:meta/meta.dart';

import 'package:whixp/src/exception.dart';
import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/plugins/rsm/rsm.dart';
import 'package:whixp/src/stanza/implementation.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/stream/matcher/matcher.dart';
import 'package:whixp/src/utils/utils.dart';
import 'package:whixp/src/whixp.dart';

import 'package:xml/xml.dart' as xml;

part 'info.dart';
part 'item.dart';
part 'static.dart';

/// ## Service Discovery
///
/// In the context of XMPP, Disco, which stands for "Service Discovery", is a
/// protocol extension that enables entities within an XMPP network to discover
/// information about the caps (capabilities) and features of other entities.
///
/// The primary goal of this extension is to provide a mechanism for
/// discovering available services, features, and identities on the network.
///
/// __See also__: [XEP-0030](http://www.xmpp.org/extensions/xep-0030.html)
class ServiceDiscovery extends PluginBase {
  /// A hirearchy of dynamic node handlers, ranging from global handlers to
  /// specialized JID+node handlers, is used by this plugin to operate.
  ///
  /// The handlers by default function in a satic way, retaining their data in
  /// memory.
  ///
  /// [wrapResults] ensures that results are wrapped in an [IQ] stanza.
  ServiceDiscovery({bool useCache = true, bool wrapResults = false})
      : super('disco', description: 'Service Discovery') {
    _useCache = useCache;
    _wrapResults = wrapResults;
  }

  late final IQ _iq;
  late final bool _useCache;
  late final bool _wrapResults;
  late final _StaticDisco _static;

  @override
  void pluginInitialize() {
    _iq = IQ(transport: base.transport);
    _static = _StaticDisco(base);

    base.transport.registerHandler(
      CallbackHandler(
        'Disco Info',
        (stanza) => _handleDiscoveryInformation(stanza as IQ),
        matcher: StanzaPathMatcher('iq/disco_info'),
      ),
    );

    base.transport.registerHandler(
      CallbackHandler(
        'Disco Items',
        (stanza) => _handleDiscoveryItems(stanza as IQ),
        matcher: StanzaPathMatcher('iq/disco_items'),
      ),
    );
  }

  /// Retrieve the disco#info results from a given JID/node combination.
  void getInformation({
    String? jid,
    String node = '',
    JabberID? iqFrom,
    bool local = false,
    bool cached = false,
  }) {
    bool localTemp = local;

    if (!local) {
      if (jid != null) {
        if (base.isComponent) {
          if (JabberID(jid).domain == base.transport.boundJID.domain) {
            localTemp = true;
          }
        } else {
          if (JabberID(jid) == base.transport.boundJID) {
            localTemp = true;
          }
        }
        jid = JabberID(jid).full;
      } else if (jid == null || jid.isEmpty) {
        localTemp = true;
      }
    }

    if (base.isComponent && iqFrom == null) {
      iqFrom = base.transport.boundJID;
    }

    if (localTemp) {
      Log.instance
          .debug('Looking up local disco#info data for $jid, node $node');

      DiscoInformationAbstract? information =
          _static.getInformation(jid: jid, node: node, iqFrom: iqFrom).concrete;

      information = _fixDefaultInformation(information);
      _wrap(iqTo: iqFrom, iqFrom: jid, payload: information);
    }

    if (cached) {
      Log.instance
          .debug('Looking up cached disco#info data for $jid, node $node');
      final information = _static.getCachedInformation()?.concrete;

      if (information != null) {
        _wrap(iqTo: iqFrom, iqFrom: jid, payload: information);
      }
    }

    _iq['from'] = iqFrom;
    _iq['to'] = jid;
    _iq['type'] = 'get';
    (_iq['disco_info'] as XMLBase)['node'] = node;
    _iq.sendIQ();
  }

  /// Retrieves the disco#items results from a given [jid]/[node] combination.
  ///
  /// Items can be obtained from both local and remote agents; the [local]
  /// parameter specifies whether executing the local node handlers will gather
  /// the items or whether generating and sending "disco#items" stanza is
  /// required.
  ///
  /// If [iterator] is `true`, loads [RSM] and returns a result set iterator
  /// using the [RSM] plugin.
  XMLBase? getItems({
    String? jid,
    String? node,
    JabberID? iqFrom,
    bool local = false,
    bool iterator = false,
  }) {
    if (local && (jid == null || jid.isEmpty)) {
      final items = _static.getItems(jid: jid, node: node, iqFrom: iqFrom);
      return _wrap(iqTo: iqFrom, iqFrom: jid, payload: items);
    }

    final iq = IQ(transport: base.transport);
    iq['from'] = iqFrom != null ? iqFrom.toString() : '';
    iq['to'] = jid;
    iq['type'] = 'get';
    (iq['disco_items'] as DiscoItemsAbstract)['node'] = node ?? '';
    final rsm = RSM(this);
    base.registerPlugin(rsm);
    if (iterator) {
      final iterator = rsm.iterate(iq, 'disco_items').iterator.iterator;
      if (iterator.moveNext()) {
        return iterator.current;
      }
    }
    iq.sendIQ();

    return iq;
  }

  /// Ensures that results are wrapped in an [IQ] stanza if [_wrapResults] has
  /// been set to `true`.
  XMLBase? _wrap({
    JabberID? iqTo,
    String? iqFrom,
    XMLBase? payload,
    bool force = false,
  }) {
    if ((force || _wrapResults) && payload is! IQ) {
      final iq = IQ();

      iq['to'] =
          iqTo != null ? iqTo.toString() : base.transport.boundJID.toString();
      iq['from'] = iqFrom ?? base.transport.boundJID.toString();
      iq['type'] = 'result';
      iq.add(Tuple2(null, payload));
      return iq;
    }

    return payload;
  }

  /// At least one identity and feature must be included in the "disco#info"
  /// results for a [JabberID]. In the event that no additional identity is
  /// supplied, [Whixp] will automatically utilize the bot client identity or
  /// the generic component.
  ///
  /// At the standart "disco#info" feature will also be added if no features
  /// are provided.
  DiscoInformationAbstract _fixDefaultInformation(
    DiscoInformationAbstract info,
  ) {
    if (info['node'] == null) {
      if (info['identities'] == null) {
        if (base.isComponent) {
          Log.instance.debug(
            'No identity found for this entity, using default component entity',
          );
        }
      }
      if (info['features'] == null) {}
    }

    return info;
  }

  /// Processes an incoming "disco#info" stanza. If it is a get request, find
  /// and return the appropriate identities and features.
  ///
  /// If it is an items result, fire the "discoInformation" event.
  void _handleDiscoveryInformation(IQ iq) {
    if (iq['type'] == 'get') {
      Log.instance.debug(
        'Received disco information query from ${iq['from']} to ${iq['to']}',
      );
      DiscoInformationAbstract information = _static
          .getInformation(
            jid: iq['to'] as String,
            node: (iq['disco_info'] as XMLBase)['node'] as String,
          )
          .concrete;

      final node = (iq['disco_info'] as XMLBase)['node'] as String;

      final reply = iq.replyIQ();

      information = _fixDefaultInformation(information);
      information['node'] = node;
      reply.setPayload([information.element!]);
      reply.sendIQ();
    } else if (iq['type'] == 'result') {
      late String? iqTo;
      Log.instance.debug(
        'Received disco information result from ${iq['from']} to ${iq['to']}',
      );

      if (_useCache) {
        Log.instance.debug(
          'Caching disco information result from ${iq['from']} to ${iq['to']}',
        );
        if (base.isComponent) {
          iqTo = JabberID(iq['to'] as String).full;
        } else {
          iqTo = null;
        }

        _static.cacheInformation(
          jid: iq['from'] as String,
          node: (iq['disco_info'] as XMLBase)['node'] as String,
          iqFrom: iqTo,
          stanza: iq,
        );
      }

      base.transport.emit<DiscoveryInformation>(
        'discoInformation',
        data: DiscoveryInformation(
          iq['disco_info'] as DiscoInformationAbstract,
        ),
      );
    }
  }

  /// Adds a [feature] to a [jid]/[node] combination.
  ///
  /// [node] and [jid] are node and jid to modify respectively.
  void addFeature(String feature, {String? jid, String? node}) =>
      _static.addFeature(feature, jid: jid, node: node);

  /// Removes a [feature] from [jid]/[node] combination.
  ///
  /// [node] and [jid] are node and jid to modify respectively.
  void removeFeature(String feature, {String? jid, String? node}) =>
      _static.removeFeature(feature, jid: jid, node: node);

  /// Processes an incoming "disco#items" stanza. If it is a get request, find
  /// and return the appropriate items. If it is an items result, fire the
  /// "discoItems" event.
  void _handleDiscoveryItems(IQ iq) {
    if (iq['type'] == 'get') {
      Log.instance.debug(
        'Received disco items query from ${iq['from']} to ${iq['to']}',
      );
    } else if (iq['type'] == 'result') {
      Log.instance.debug(
        'Received disco items result from ${iq['from']} to ${iq['to']}',
      );
      base.transport.emit<DiscoveryItems>(
        'discoItems',
        data: DiscoveryItems(iq['disco_items'] as DiscoItemsAbstract),
      );
    }
  }

  @override
  void pluginEnd() => addFeature(WhixpUtils.getNamespace('DISCO_INFO'));

  @override
  void sessionBind(String? jid) =>
      removeFeature(WhixpUtils.getNamespace('DISCO_INFO'));
}
