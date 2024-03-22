import 'dart:async';

import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/plugins/form/dataforms.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stream/base.dart';

import 'package:xml/xml.dart' as xml;

part 'stanza.dart';

class Push extends PluginBase {
  Push()
      : super(
          'push',
          description: 'XEP-0357: Push Notifications',
          dependencies: {'disco'},
        );

  @override
  void pluginInitialize() {}

  FutureOr<IQ> enablePush<T>(
    JabberID jid, {
    required String node,
    Form? config,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 10,
  }) {
    final iq = base.makeIQSet();
    final enable = _EnablePush();
    enable['jid'] = jid.bare;
    enable['node'] = node;

    if (config != null) enable.add(config);

    iq.add(enable);

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  FutureOr<IQ> disablePush<T>(
    JabberID jid, {
    String? node,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 10,
  }) {
    final iq = base.makeIQSet();
    final disable = _DisablePush();
    disable['jid'] = jid.bare;
    disable['node'] = node;

    iq.add(disable);

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Do not implement.
  @override
  void sessionBind(String? jid) {}

  /// Do not implement.
  @override
  void pluginEnd() {}
}
