part of 'rsm.dart';

/// XEP-0059 (Result Set Management) can be used to handle query results.
///
/// Limiting the quantity of things per answer, for example, or starting at
/// specific points.
///
/// ### Example:
/// ```xml
/// <iq type='set' from='stpeter@jabber.org/roundabout' to='users.jabber.org' id='limit1'>
///   <query xmlns='jabber:iq:search'>
///     <nick>Pete</nick>
///     <set xmlns='http://jabber.org/protocol/rsm'>
///       <max>10</max>
///     </set>
///   </query>
/// </iq>
///
/// returns a limited result set
///
/// <iq type='result' from='users.jabber.org' to='stpeter@jabber.org/roundabout' id='limit1'>
///   <query xmlns='jabber:iq:search'>
///     <item jid='stpeter@jabber.org'>
///       <first>Peter</first>
///       <last>Saint-Andre</last>
///       <nick>Pete</nick>
///     </item>
///     .
///     [8 more items]
///     .
///     <item jid='peterpan@neverland.lit'>
///       <first>Peter</first>
///       <last>Pan</last>
///       <nick>Pete</nick>
///     </item>
///   </query>
/// </iq>
/// ```
///
/// see <https://xmpp.org/extensions/xep-0059.html>
class RSMStanza extends XMLBase {
  /// Creates [RSMStanza] stanza with optional parameters.
  ///
  /// ### interfaces:
  ///
  /// __first_index__ is the attribute of __first__
  /// <br>__after__ is the ID defining from which item to start
  /// <br>__before__ is the ID defining from which item to start when browsing
  /// backwards
  /// <br>__max__ is the max amount per response
  /// <br>__first__ is ID for the first item in the response
  /// <br>__last__ is ID for the last item in the response
  /// <br>__index__ is used to set an index to start from
  /// <br>__count__ is the number of remote items available
  RSMStanza({super.element, super.parent})
      : super(
          name: 'set',
          namespace: WhixpUtils.getNamespace('RSM'),
          includeNamespace: true,
          pluginAttribute: 'rsm',
          interfaces: {
            'first_index',
            'first',
            'after',
            'before',
            'count',
            'index',
            'last',
            'max',
          },
          subInterfaces: {
            'first',
            'after',
            'before',
            'count',
            'index',
            'last',
            'max',
          },
        );

  /// Returns the value of the `index` attribute for __first__.
  String get firstIndex {
    final first = element!.getElement('first', namespace: namespace);
    if (first != null) {
      return first.getAttribute('index') ?? '';
    }
    return '';
  }

  /// Sets the `index` attribute for __first__ and creates the element if it
  /// does not exist.
  void setFirstIndex(String index) {
    final first = element!.getElement('first', namespace: namespace);
    if (first != null) {
      if (index.isNotEmpty) {
        first.setAttribute('index', index);
      } else if (first.getAttribute('index') != null) {
        first.removeAttribute('index');
      }
    } else if (index.isNotEmpty) {
      final first = WhixpUtils.xmlElement('first');
      first.setAttribute('index', index);
      element!.children.add(first);
    }
  }

  /// Removes the `index` attribute for __first__, but keeps the element.
  void deleteFirstIndex() {
    final first = element!.getElement('first', namespace: namespace);
    if (first != null) {
      first.removeAttribute('index', namespace: namespace);
    }
  }

  /// Sets the [value] of __before__, if the [value] is `true`, then the element
  /// will be created without a [value].
  void setBefore(dynamic value) {
    final before = element!.getElement('before', namespace: namespace);
    if (before == null && value == true) {
      setSubText('{$namespace}before', text: '', keep: true);
    } else if (value is String) {
      setSubText('{$namespace}before', text: value);
    }
  }

  /// Returns the value of __before__, if it is empty it will return `true`.
  dynamic get before {
    final before = element!.getElement('before', namespace: namespace);
    if (before != null && before.innerText.isEmpty) {
      return true;
    } else if (before != null) {
      return before.innerText;
    }
    return null;
  }

  @override
  RSMStanza copy({xml.XmlElement? element, XMLBase? parent}) => RSMStanza(
        element: element,
        parent: parent,
      );
}
