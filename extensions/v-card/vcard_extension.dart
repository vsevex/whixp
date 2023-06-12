import 'package:echo/src/builder.dart';
import 'package:echo/src/constants.dart';

import 'package:xml/xml.dart' as xml;

import '../extension.dart';

part 'vcard.dart';

class VCardExtension extends Extension<VCard> {
  VCardExtension(super.echo, {this.handlerID = 'v-card'});

  final String handlerID;

  @override
  Future<VCard> trigger(
    String jid, {
    void Function(xml.XmlElement)? callback,
    void Function(xml.XmlElement?)? onError,
  }) async {
    final iq = EchoBuilder.iq(
      attributes: {'type': 'get', 'to': jid},
    ).c('vCard', attributes: {'xmlns': ns['VCARD']!});

    await echo.sendIQ(
      element: iq.nodeTree!,
      callback: callback,
      onError: onError,
    );
  }
}
