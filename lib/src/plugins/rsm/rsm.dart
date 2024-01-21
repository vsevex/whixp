import 'dart:async';

import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/plugins/disco/disco.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

part 'stanza.dart';

/// Result Set Management plugin
class RSM extends PluginBase {
  RSM()
      : super(
          'RSM',
          description: 'XEP-0059: Result Set Management',
          dependencies: {'disco'},
        );

  late final ServiceDiscovery? _disco;

  /// Do not implement.
  @override
  void pluginInitialize() {}

  @override
  void sessionBind(String? jid) {
    _disco = base.getPluginInstance<ServiceDiscovery>('disco');
    if (_disco != null) {
      _disco.addFeature(RSMStanza().namespace);
    }
  }

  @override
  void pluginEnd() => _disco?.removeFeature(RSMStanza().namespace);

  _ResultIterable iterate(
    IQ stanza,
    String interface, {
    int amount = 10,
    bool reverse = false,
    String receiveInterface = '',
    XMLBase? receiveInterfaceStanza,
    T Function<T>(IQ iq)? preCallback,
    FutureOr<void> Function(IQ iq)? postCallback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 10,
  }) =>
      _ResultIterable(
        _ResultIterator(
          stanza,
          interface,
          amount: amount,
          reverse: reverse,
          receiveInterface:
              receiveInterface.isEmpty ? interface : receiveInterface,
          preCallback: preCallback,
          postCallback: postCallback,
          failureCallback: failureCallback,
          timeoutCallback: timeoutCallback,
          timeout: timeout,
        ),
      );
}

/// An iterator or Result Set Management
class _ResultIterator {
  _ResultIterator(
    this._query,
    this._interface, {
    required int amount,
    required bool reverse,
    required String receiveInterface,
    T Function<T>(IQ iq)? preCallback,
    FutureOr<void> Function(IQ iq)? postCallback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 10,
  }) {
    _amount = amount;
    _reverse = reverse;
    _receiveInterface = receiveInterface;
    _preCallback = preCallback;
    _postCallback = postCallback;
    _failureCallback = failureCallback;
    _timeoutCallback = timeoutCallback;
    _timeout = timeout;
  }

  bool _stop = false;
  String? start;

  final IQ _query;
  final String _interface;
  late final int _amount;
  late final bool _reverse;
  late final String _receiveInterface;
  late final T Function<T>(IQ iq)? _preCallback;
  late final FutureOr<void> Function(IQ iq)? _postCallback;
  FutureOr<void> Function(StanzaError error)? _failureCallback;
  FutureOr<void> Function()? _timeoutCallback;
  int _timeout = 10;
}

class _ResultIterable extends Iterable<Future<StanzaBase?>> {
  _ResultIterable(this.base);

  final _ResultIterator base;

  @override
  Iterator<Future<StanzaBase?>> get iterator => _ResultIteratorBase(base);
}

class _ResultIteratorBase implements Iterator<Future<StanzaBase?>> {
  _ResultIteratorBase(this.iterator);

  final _ResultIterator iterator;

  @override
  Future<StanzaBase?> get current async {
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
      IQ? stanza;

      await iterator._query.sendIQ(
        callback: (iq) async {
          final received = iq[iterator._receiveInterface] as XMLBase;

          if ((received['rsm'] as RSMStanza)['first'] == null &&
              (received['rsm'] as RSMStanza)['last'] == null) {
            throw Exception('Stop stanza iteration: $iq');
          }

          if (iterator._postCallback != null) {
            await iterator._postCallback!.call(iq);
          }

          if ((received['rsm'] as RSMStanza)['count'] != null &&
              (received['rsm'] as RSMStanza)['first_index'] != null) {
            final count = int.parse(
              (received['rsm'] as RSMStanza)['count'] as String,
            );
            final first = int.parse((received['rsm'] as RSMStanza).firstIndex);

            final numberItems =
                (received['substanzas'] as List<XMLBase>).length;
            if (first + numberItems == count) {
              iterator._stop = true;
            }
          }

          if (iterator._reverse) {
            iterator.start = (received['rsm'] as RSMStanza)['first'] as String;
          } else {
            iterator.start = (received['rsm'] as RSMStanza)['last'] as String;
          }

          stanza = iq;
        },
        failureCallback: iterator._failureCallback,
        timeoutCallback: iterator._timeoutCallback,
        timeout: iterator._timeout,
      );

      return Future.value(stanza);
    } on Exception {
      iterator._stop = true;
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
