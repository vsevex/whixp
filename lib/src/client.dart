import 'package:echox/src/handler/callback.dart';
import 'package:echox/src/stanza/features.dart';
import 'package:echox/src/stream/matcher/xpath.dart';
import 'package:echox/src/whixp.dart';

class Whixp extends WhixpBase {
  Whixp(
    String jabberID, {
    super.host,
    super.port,
    this.language = 'en',
    super.useTLS = false,
  }) : super(jabberID: jabberID) {
    /// Set [streamHeader] of declared transport for initial send.
    transport.streamHeader =
        "<stream:stream to='${boundJID.host}' xmlns:stream='$streamNamespace' xmlns='$defaultNamespace' xml:lang='$language' version='1.0'>";

    transport
      ..registerStanza(StreamFeatures())
      ..registerHandler(
        FutureCallbackHandler(
          'Stream Features',
          (stanza) => _handleStreamFeatures(stanza as StreamFeatures),
          matcher: XPathMatcher('<features xmlns="$streamNamespace"/>'),
        ),
      );
  }

  /// Default language to use in stanza communication.
  final String language;

  Future<void> _handleStreamFeatures(StreamFeatures features) async {
    print(features);
  }

  void connect() {
    transport.connect();
  }
}
