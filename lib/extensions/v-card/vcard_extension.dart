import 'package:echo/echo.dart';
import 'package:echo/extensions/event/event.dart';
import 'package:echo/src/constants.dart';

part 'vcard.dart';

/// Extension class for vCard functionality in the XMPP server.
///
/// This class extends the base `Extension` class from the [Echo] package and
/// provides methods to interact with vCard data.
///
/// It allows retrieving and updating vCard information for specfic Jabber IDs
/// in the server.
class VCardExtension extends Extension<VCard> {
  /// Creates an instance of the [VCard] extension class.
  ///
  /// ### Usage
  /// ```dart
  /// final extension = VCardExtension();
  ///
  /// echo.attachExtension(extension);
  ///
  /// /// ...for more information please refer to `attachExtension` method.
  /// ```
  VCardExtension() : super('v-card-extension');

  /// Initialize [vCardEvent] object to listen later changes of the current card.
  final vCardEvent = Eventius<VCard>(name: 'v-card');

  /// Initializer method for [Extension].
  @override
  void initialize(Echo echo) {
    this.echo = echo;
  }

  /// Retrieves the vCard information for specified JID from the server.
  ///
  /// * @param jid The JID for which to retrieve the vCard.
  /// * @param callback Optional callback function to handle the successful
  /// response.
  /// * @param onError Optional callback function to handle errors.
  /// * @return A [Future] that returns void.
  /// * @throws AssertionError if the JID is not provided.
  Future<void> get({
    String? jid,
    void Function(XmlElement)? callback,
    void Function(XmlElement?)? onError,
  }) async {
    assert(jid != null, 'JID must be provided in order to get vCard.');

    /// Declares empty [VCard].
    VCard vCard = const VCard();

    /// Sends initial get response to the server with the corresponding JID.
    await echo!.sendIQ(
      element: _buildIQ(
        'get',
        jid: jid,
      ),
      callback: (element) {
        /// Map all children elements of the given element.
        for (final child in element.descendantElements) {
          if (child.localName == 'FN') {
            vCard = vCard.copyWith(fullName: child.innerText);
          }
          if (child.localName == 'NICKNAME') {
            vCard = vCard.copyWith(nickname: child.innerText);
          }
          if (child.localName == 'PHOTO') {
            vCard = vCard.copyWith(photo: child.innerText);
          }
          if (child.localName == 'EMAIL') {
            vCard = vCard.copyWith(email: child.innerText);
          }
          if (child.localName == 'TEL') {
            vCard = vCard.copyWith(phoneNumber: child.innerText);
          }
          if (child.localName == 'TZ') {
            vCard = vCard.copyWith(timezone: child.innerText);
          }
        }

        /// Send gathered vCard information to notify event listener.
        vCardEvent.fire(vCard);

        /// If the callback is provided, then call this after mapping is done.
        if (callback != null) {
          callback.call(element);
        }
      },
      onError: onError,
    );
  }

  /// Sets the vCard information.
  ///
  /// * @param vCard The VCard representing the vCard information.
  /// payload format. See the usage of payload in [VCard].
  /// * @param callback Optional callback function to handle the successful
  /// response.
  /// * @param onError Optional callback function to handle errors.
  /// * @return A [Future] that resolves to the retrieved vCard information.
  /// * @throws AssertionError if the vCard is not provided.
  Future<void> set({
    VCard? vCard,
    void Function(XmlElement)? callback,
    void Function(XmlElement?)? onError,
  }) {
    assert(vCard != null, 'vCard must be provided.');

    return echo!.sendIQ(
      element: _buildIQ('set', vCard: vCard),
      callback: callback,
      onError: onError,
    );
  }

  /// Builds the IQ stanza for vCard operations.
  ///
  /// * @param type The IQ type ('get' or 'set').
  /// * @param jid Optional JID to include in the stanza.
  /// * @param vCard Optional vCard as a [VCard] to include in the stanza.
  XmlElement _buildIQ(
    String type, {
    String? jid,
    VCard? vCard,
  }) {
    final iq = EchoBuilder.iq(
      attributes: jid == null ? {'type': type} : {'type': type, 'to': jid},
    ).c('vCard', attributes: {'xmlns': ns['VCARD']!});

    /// Checks if vCard is not null. Then add as a text node.
    if (vCard != null) {
      for (final element in vCard.payload) {
        iq.cnode(element);
      }
    }

    return iq.nodeTree!;
  }
}
