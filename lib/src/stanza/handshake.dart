import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/stream/base.dart';
import 'package:xml/xml.dart';

/// External source for expanded version of the given stanza's purpose:
/// https://xmpp.org/extensions/xep-0114.html
///
/// The main difference between the **jabber:component:** namespaces and the
/// **jabber:client** or **jabber:server** `namespace` is authentication.
///
/// This stanza uses <handshake/> element to specify credentials for the
/// component's session with the server.
///
/// Component sends this stanza:
/// ```xml
/// <stream:stream
/// xmlns='jabber:component:accept'
/// xmlns:stream='http://etherx.jabber.org/streams'
/// to='plays.shakespeare.lit'>
/// ```
///
/// `to` identifier in this case refers to component name, not the server name.
class Handshake extends StanzaBase {
  Handshake()
      : super(
          name: 'handshake',
          namespace: Echotils.getNamespace('COMPONENT'),
          interfaces: {
            'value',
          },
          setters: {
            const Symbol('value'): (value, args, base) =>
                base.element?.innerText = value as String,
          },
          getters: {
            const Symbol('value'): (args, base) => base.element?.innerText,
          },
          deleters: {
            const Symbol('value'): (args, base) => base.element?.innerText = '',
          },
        );
}
