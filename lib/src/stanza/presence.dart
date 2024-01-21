import 'package:whixp/src/plugins/delay/delay.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/root.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

/// XMPP's <presence> stanza allows entities to know the status of other clients
/// and components. Since it is currently the only multi-cast stanza in XMPP,
/// many extensions and more information to [Presence] stanzas to broadcast
/// to every entry in the roster, such as capabilities, music choices, or
/// locations.
///
/// Since [Presence] stanzas are broadcast when an XMPP entity changes its
/// status, the bulk of the traffic in an XMP network will be from <presence>
/// stanazas. Therefore, do not include more information than necessary in a
/// status message or within a [Presence] stanza in order to help keep the
/// network running smoothly.
///
/// ### Example:
/// ```xml
/// <presence from="vsevex@example.com">
/// <show>away</show>
///   <status>old, but platin</status>
///   <priority>1</priority>
/// </presence>
/// ```
class Presence extends RootStanza {
  Presence({
    /// [showtypes] may be one of: dnd, chat, xa, away.
    this.showtypes = const {'dnd', 'chat', 'xa', 'away'},
    super.transport,
    super.stanzaType,
    super.stanzaTo,
    super.stanzaFrom,
    super.receive = false,
    super.includeNamespace = false,
    super.getters,
    super.setters,
    super.deleters,
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.pluginMultiAttribute,
    super.pluginIterables,
    super.overrides,
    super.isExtension,
    super.boolInterfaces,
    super.element,
    super.parent,
  }) : super(
          name: 'presence',
          namespace: WhixpUtils.getNamespace('CLIENT'),
          pluginAttribute: 'presence',
          interfaces: <String>{
            'type',
            'to',
            'from',
            'id',
            'show',
            'status',
            'priority',
          },
          subInterfaces: <String>{'show', 'status', 'priority'},
          languageInterfaces: <String>{'status'},
          types: <String>{
            'available',
            'unavailable',
            'error',
            'probe',
            'subscribe',
            'subscribed',
            'unsubscribe',
            'unsubscribed',
          },
        ) {
    if (!receive && this['id'] == '') {
      if (transport != null) {
        this['id'] = WhixpUtils.getUniqueId();
      }
    }

    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('type'): (args, base) {
        String out = base.getAttribute('type');
        if (out.isEmpty && showtypes.contains(base['show'])) {
          out = this['show'] as String;
        }
        if (out.isEmpty) {
          out = 'available';
        }
        return out;
      },
      const Symbol('priority'): (args, base) {
        String presence = base.getSubText('priority') as String;
        if (presence.isEmpty) {
          presence = '0';
        }
        return presence;
      },
    });

    addSetters(
      <Symbol, void Function(dynamic value, dynamic args, XMLBase base)>{
        const Symbol('type'): (value, args, base) {
          if (types.contains(value)) {
            base['show'] = null;
            if (value == 'available') {
              value = '';
            }
            base.setAttribute('type', value as String);
          } else if (showtypes.contains(value)) {
            base['show'] = value;
          }
        },
        const Symbol('priority'): (value, args, base) => base.setSubText(name),
        const Symbol('show'): (value, args, base) {
          final show = value as String?;
          if (show == null || show.isEmpty) {
            deleteSub('show');
          } else if (showtypes.contains(show)) {
            setSubText('show', text: show);
          }
        },
      },
    );

    addDeleters(
      <Symbol, void Function(dynamic args, XMLBase base)>{
        const Symbol('type'): (args, base) {
          base.deleteAttribute('type');
          base.deleteSub('show');
        },
      },
    );

    /// Register all required stanzas beforehand, so we won't need to declare
    /// them one by one whenever there is a need to specific stanza.
    ///
    /// If you have not used the specified stanza, then you have to enable the
    /// stanza through the usage of `pluginAttribute` parameter.
    registerPlugin(StanzaError());
    registerPlugin(DelayStanza());
  }

  /// Creates a new reply [Presence] from the current stanza.
  Presence replyPresence({bool clear = true}) {
    final presence = super.reply<Presence>(copiedStanza: copy(), clear: clear);

    if (this['type'] == 'unsubscribe') {
      presence['type'] = 'unsubscribed';
    } else if (this['type'] == 'subscribe') {
      presence['type'] = 'subscribed';
    }

    return presence;
  }

  @override
  Presence copy({
    xml.XmlElement? element,
    XMLBase? parent,
    bool receive = false,
  }) =>
      Presence(
        transport: transport,
        receive: receive,
        includeNamespace: includeNamespace,
        getters: getters,
        setters: setters,
        deleters: deleters,
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        pluginMultiAttribute: pluginMultiAttribute,
        pluginIterables: pluginIterables,
        overrides: overrides,
        isExtension: isExtension,
        boolInterfaces: boolInterfaces,
        element: element,
        parent: parent,
      );

  /// [showtypes] may be one of: dnd, chat, xa, away.
  final Set<String> showtypes;
}
