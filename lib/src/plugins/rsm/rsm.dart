import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/plugins/disco/disco.dart';
import 'package:whixp/src/plugins/rsm/stanza.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/utils/utils.dart';

/// Result Set Management plugin
class RSM extends PluginBase {
  RSM(this._disco)
      : super(
          'RSM',
          description: 'XEP-0059: Result Set Management',
          dependencies: {'disco'},
        );

  final ServiceDiscovery _disco;

  @override
  void pluginInitialize() {}

  @override
  void sessionBind(String? jid) => _disco.addFeature(RSMStanza().namespace);

  @override
  void pluginEnd() => _disco.removeFeature(RSMStanza().namespace);

  _ResultIterator iterate(
    IQ stanza,
    String interface, {
    String results = 'substanzas',
    int amount = 10,
    bool reverse = false,
    String receiveInterface = '',
    T Function<T>(IQ stanza)? preCallback,
    XMLBase? receiveInterfaceStanza,
    B Function<B>(StanzaBase stanza)? postCallback,
  }) =>
      _ResultIterator(
        stanza,
        interface,
        amount: amount,
        reverse: reverse,
        receiveInterface: receiveInterface,
        preCallback: preCallback,
        receiveInterfaceStanza: receiveInterfaceStanza,
        postCallback: postCallback,
      );
}

/// An iterator or Result Set Management
class _ResultIterator {
  _ResultIterator(
    this._query,
    this._interface, {
    String receiveInterface = '',
    int amount = 10,
    bool reverse = false,
    T Function<T>(IQ stanza)? preCallback,
    XMLBase? receiveInterfaceStanza,
    B Function<B>(StanzaBase stanza)? postCallback,
  }) {
    _receiveInterface = receiveInterface;
    _amount = amount;
    _reverse = reverse;
    _preCallback = preCallback;
    _receiveInterfaceStanza = receiveInterfaceStanza;
    _postCallback = postCallback;

    iterator = _ResultIterable(this);
  }

  bool _stop = false;
  late final bool _reverse;
  final IQ _query;
  final String _interface;
  late final String _receiveInterface;
  String? start;
  late final T Function<T>(IQ stanza)? _preCallback;
  late final B Function<B>(StanzaBase stanza)? _postCallback;
  late final XMLBase? _receiveInterfaceStanza;
  late final int _amount;

  late final _ResultIterable iterator;
}

class _ResultIterable extends Iterable<StanzaBase?> {
  _ResultIterable(this.base);

  final _ResultIterator base;

  @override
  Iterator<StanzaBase?> get iterator => _ResultIteratorBase(base);
}

class _ResultIteratorBase implements Iterator<StanzaBase?> {
  _ResultIteratorBase(this.iterator);

  final _ResultIterator iterator;

  @override
  StanzaBase? get current {
    iterator._query['id'] = WhixpUtils.getUniqueId('rsm');
    ((iterator._query[iterator._interface] as XMLBase)['rsm']
        as RSMStanza)['max'] = iterator._amount.toString();

    if (iterator.start != null) {
      if (iterator._reverse) {
        ((iterator._query[iterator._interface] as XMLBase)['rsm']
            as RSMStanza)['before'] = iterator.start;
      } else {
        ((iterator._query[iterator._interface] as XMLBase)['rsm']
            as RSMStanza)['after'] = iterator.start;
      }
    } else if (iterator._reverse) {
      ((iterator._query[iterator._interface] as XMLBase)['rsm']
          as RSMStanza)['before'] = true;
    }

    try {
      if (iterator._preCallback != null) {
        iterator._preCallback?.call(iterator._query);
      }
      late StanzaBase base;
      iterator._query.sendIQ(
        callback: (stanza) {
          if (iterator._receiveInterfaceStanza != null) {
            stanza.registerPlugin(iterator._receiveInterfaceStanza!);
            if (((stanza[iterator._receiveInterface] as XMLBase)['rsm']
                        as RSMStanza)['first'] !=
                    null &&
                ((stanza[iterator._receiveInterface] as XMLBase)['rsm']
                        as RSMStanza)['last'] !=
                    null) {
              return false;
            }

            if (iterator._postCallback != null) {
              iterator._postCallback?.call(stanza);
            }

            if (((stanza[iterator._receiveInterface] as XMLBase)['rsm']
                        as RSMStanza)['count'] !=
                    null &&
                ((stanza[iterator._receiveInterface] as XMLBase)['rsm']
                        as RSMStanza)['firstIndex'] !=
                    null) {
              // final count = int.parse(((stanza[iterator._receiveInterface] as XMLBase)['rsm'] as RSMStanza)['count'] as String);
              // final first = int.parse(((stanza[iterator._receiveInterface] as XMLBase)['rsm'] as RSMStanza)['firstIndex'] as String);
              iterator._stop = true;
            }

            if (iterator._reverse) {
              iterator.start = ((stanza[iterator._receiveInterface]
                  as XMLBase)['rsm'] as RSMStanza)['first'] as String;
            } else {
              iterator.start = ((stanza[iterator._receiveInterface]
                  as XMLBase)['rsm'] as RSMStanza)['last'] as String;
            }

            base = stanza;
          }
        },
      );

      return base;
    } on Exception {
      return null;
    }
  }

  @override
  bool moveNext() {
    if (iterator._stop) {
      return false;
    }
    return true;
  }
}
