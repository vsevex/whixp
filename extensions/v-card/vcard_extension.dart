import 'package:echo/echo.dart';
import 'package:echo/src/constants.dart';
import 'package:echo/src/extension.dart';

part 'vcard.dart';

class VCardExtension extends Extension<VCard> {
  VCardExtension() : super('v-card-extension');

  @override
  void initialize(Echo echo) {
    this.echo = echo;
  }

  @override
  Future<VCard> get({
    String? jid,
    void Function(XmlElement)? callback,
    void Function(XmlElement?)? onError,
  }) async {
    assert(jid != null, 'JID must be given in order to get vCard data');
    await echo!.sendIQ(
      element: _buildIQ(
        'get',
        jid: jid,
      ),
      callback: callback,
      onError: onError,
    );

    return const VCard('Anar Bayram');
  }

  @override
  Future<void> set({
    String? jid,
    XmlElement? vCardElement,
    void Function(XmlElement)? callback,
    void Function(XmlElement?)? onError,
  }) =>
      echo!.sendIQ(
        element: _buildIQ('set', jid: jid, element: vCardElement),
        callback: callback,
        onError: onError,
      );

  XmlElement _buildIQ(String type, {String? jid, XmlElement? element}) {
    final iq = EchoBuilder.iq(
      attributes: jid == null ? {'type': type} : {'type': type, 'to': jid},
    ).c('vCard', attributes: {'xmlns': ns['VCARD']!});
    if (element != null) {
      iq.cnode(element);
    }

    return iq.nodeTree!;
  }
}
