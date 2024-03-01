import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/stanza/features.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/stream/matcher/matcher.dart';

import 'package:xml/xml.dart' as xml;

part 'stanza.dart';

class Compression extends PluginBase {
  Compression()
      : super(
          'compression',
          description: 'XEP-0138: Compression',
          dependencies: <String>{'disco'},
        );

  late final Map<String, bool> _compressionMethods;

  @override
  void pluginInitialize() {
    _compressionMethods = <String, bool>{'zlib': true};

    base.transport
      ..registerStanza(Compress())
      ..registerStanza(Compressed())
      ..registerHandler(
        CallbackHandler(
          'Compressed',
          _handleCompressed,
          matcher:
              XPathMatcher('{http://jabber.org/protocol/compress}compressed'),
        ),
      );

    base.registerFeature(
      'compression',
      (stanza) => _handleCompression(stanza as StreamFeatures),
      restart: true,
      order: 5,
    );
  }

  bool _handleCompression(StreamFeatures features) {
    for (final method in (features['compression']
        as CompressionStanza)['methods'] as Set<String>) {
      if (_compressionMethods.containsKey(method)) {
        Log.instance.info('Attempting to use $method compression');
        final compress = Compress();
        compress.transport = base.transport;
        compress['method'] = method;
        compress.send();
        return true;
      }
    }
    return false;
  }

  void _handleCompressed(StanzaBase stanza) {
    base.features.add('compression');
    Log.instance.debug('Stream Compressed!!!');
    // base.transport.streamCompressed = true;
  }

  /// Do not implement.
  @override
  void sessionBind(String? jid) {}

  /// Do not implement.
  @override
  void pluginEnd() {}
}
