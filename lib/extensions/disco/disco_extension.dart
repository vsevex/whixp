import 'dart:async';

import 'package:echo/echo.dart';
import 'package:echo/src/constants.dart';

part 'identity.dart';
part 'item.dart';

/// Represents a Disco Extension.
///
/// The [DiscoExtension] class extends [Extension] class and provides
/// functionality related to Disco (Service Discovery) (XEP-0030) protocol.
///
/// It allows discovering information about entities, such as their identities,
/// features and items.
class DiscoExtension extends Extension {
  /// Creates a [DiscoExtension] instance.
  DiscoExtension() : super('disco-extension');

  /// The list of [DiscoItem] objects.
  late final _items = <DiscoItem>[];

  /// The list of feature strings.
  late final _features = <String>[];

  /// The list of [DiscoIdentity] objects.
  late final _identities = <DiscoIdentity>[];

  /// This method is not implemented and will not be affected in the use of this
  /// extension.
  @override
  void changeStatus(EchoStatus status, String? condition) {
    // throw ExtensionException.notImplementedFeature(
    //   'Disco',
    //   'Changing Connection Status',
    // );
  }

  @override
  void initialize(Echo echo) {
    super.echo = echo;

    /// Add required namespaces to the [Echo] class.
    super.echo!
      ..addHandler(
        _onDiscoInfo,
        namespace: ns['DISCO_INFO'],
        name: 'iq',
        type: 'get',
      )
      ..addHandler(
        _onDiscoItems,
        namespace: ns['DISCO_ITEMS'],
        name: 'iq',
        type: 'get',
      );
  }

  /// Adds a new identity to the extension.
  ///
  /// * @param category Specifies the category of the identity.
  /// * @param type Specifies the type of the identity.
  /// * @param name Specifies the name of the identity. Defaults to empty
  /// string.
  /// * @param language Specifies the language associated with the identity.
  /// Defaults to empty string.
  /// * @return `true` if the identity was added successfully, or `false` if an
  /// identity with the same category, type, name, and language already exists.
  bool addIdentity({
    required String category,
    required String type,
    String name = '',
    String language = '',
  }) {
    for (int i = 0; i < _identities.length; i++) {
      if (_identities[i].category == category &&
          _identities[i].type == type &&
          _identities[i].name == name &&
          _identities[i].language == language) {
        return false;
      }
    }

    _identities.add(
      DiscoIdentity(
        category: category,
        type: type,
        name: name,
        language: language,
      ),
    );
    return true;
  }

  /// Sends a Disco info request to the specified JID.
  ///
  /// * @param jid Specifies the JID to send the request to.
  /// * @param node Specifies the node associated with the request. Defaults to
  /// `null`.
  /// * @param resultCallback Specifies the callback function to be executed
  /// when the request succeeds. Defaults to `null`.
  /// * @param errorCallback Specifies the callback function to be executed when
  /// an error occurs. Defaults to `null`.
  /// * @param timeout Specifies the timeout duration to be passed to the method
  /// of `sendIQ`.
  Future<void> info(
    String jid, {
    String? node,
    FutureOr<void> Function(XmlElement)? resultCallback,
    FutureOr<void> Function(EchoException)? errorCallback,
    int? timeout,
  }) async {
    final attributes = <String, String>{'xmlns': ns['DISCO_INFO']!};

    if (node != null) {
      attributes['node'] = node;
    }

    final info = EchoBuilder.iq(
      attributes: {'from': echo!.jid, 'to': jid, 'type': 'get'},
    ).c('query', attributes: attributes);

    return echo!.sendIQ(
      element: info.nodeTree!,
      resultCallback: resultCallback,
      errorCallback: errorCallback,
      waitForResult: true,
      timeout: timeout,
    );
  }

  /// Sends a Disco items request to the specified JID.
  ///
  /// * @param jid Specifies the JID to send the request to.
  /// * @param node Specifies the node associated with the request.
  /// * @param resultCallback Specifies the callback function to be executed
  /// when the request succeeds.
  /// * @param errorCallback Specifies the callback function to be executed when
  /// an error occurs. Defaults to `null`.
  /// * @param timeout Specifies the timeout duration to be passed to the method
  /// of `sendIQ`.
  Future<void> items(
    String jid, {
    String? node,
    FutureOr<void> Function(XmlElement)? resultCallback,
    FutureOr<void> Function(EchoException)? errorCallback,
    int? timeout,
  }) async {
    final attributes = <String, String>{'xmlns': ns['DISCO_ITEMS']!};

    if (node != null) {
      attributes['node'] = node;
    }

    final items = EchoBuilder.iq(
      attributes: {'from': echo!.jid, 'to': jid, 'type': 'get'},
    ).c('query', attributes: attributes);

    return echo!.sendIQ(
      element: items.nodeTree!,
      resultCallback: resultCallback,
      errorCallback: errorCallback,
      waitForResult: true,
      timeout: timeout,
    );
  }

  /// Adds a feature to the extension.
  ///
  /// * @param variableName Specifies the name of the feature.
  /// * @return `true` if the feature was added successfully, or `false` if the
  /// feature already exists.
  bool addFeature(String variableName) {
    for (int i = 0; i < _features.length; i++) {
      if (_features[i] == variableName) {
        return false;
      }
    }
    _features.add(variableName);
    return true;
  }

  /// Removes a feature from the extension.
  ///
  /// * @param variableName Specifies the name of the feature.
  /// * @return `true` feature was removed successfully, or `false` if the
  /// feature does not exist.
  bool removeFeature(String variableName) {
    for (int i = 0; i < _features.length; i++) {
      if (_features[i] == variableName) {
        _features.removeAt(i);
        return true;
      }
    }
    return false;
  }

  /// Handles a Disco info request received in a stanza.
  ///
  /// * @param stanza Specifies the received stanza.
  /// * @return `true` if the handling is successful.
  bool _onDiscoInfo(XmlElement stanza) {
    final node = stanza.findElements('query').toList()[0].getAttribute('node');
    Map<String, String> attributes = {'xmlns': ns['DISCO_INFO']!};
    if (node != null) {
      attributes['node'] = node;
    }

    final iqResult =
        _buildIQResult(stanza: stanza, queryAttributes: attributes);

    for (int i = 0; i < _identities.length; i++) {
      attributes = {
        'category': _identities[i].category,
        'type': _identities[i].type
      };
      if (_identities[i].name != null) {
        attributes['name'] = _identities[i].name!;
      }
      if (_identities[i].language != null) {
        attributes['language'] = _identities[i].language!;
      }
      iqResult.c('identity', attributes: attributes).up();
    }

    for (int i = 0; i < _features.length; i++) {
      iqResult.c('feature', attributes: {'var': _features[i]}).up();
    }

    echo!.send(iqResult.nodeTree);
    return true;
  }

  /// Handles a Disco items request received in a stanza.
  ///
  /// * @param stanza Specifies the received stanza.
  /// * @return `true` if the handling is successful.
  bool _onDiscoItems(XmlElement stanza) {
    final attributes = {'xmlns': ns['DISCO_ITEMS']!};
    final node = stanza.findElements('query').toList()[0].getAttribute('node');
    List<DiscoItem> items = [];
    if (node != null) {
      attributes['node'] = node;
      items = [];

      for (int i = 0; i < _items.length; i++) {
        if (_items[i].node == node) {
          items = _items[i].callback(stanza);
          break;
        }
      }
    } else {
      items = _items;
    }

    final iqResult =
        _buildIQResult(stanza: stanza, queryAttributes: attributes);
    for (int i = 0; i < items.length; i++) {
      final attributes = <String, String>{'jid': items[i].jid};
      if (items[i].name != null) {
        attributes['name'] = items[i].name!;
      }
      if (items[i].node != null) {
        attributes['node'] = items[i].node!;
      }
      iqResult.c('item', attributes: attributes).up();
    }
    echo!.send(iqResult.nodeTree);
    return true;
  }

  EchoBuilder _buildIQResult({
    required XmlElement stanza,
    required Map<String, String> queryAttributes,
  }) {
    final id = stanza.getAttribute('id');
    final from = stanza.getAttribute('from');
    final iqResult = EchoBuilder.iq(attributes: {'type': 'result', 'id': id});

    if (from != null) {
      iqResult.addAttributes({'to': from});
    }

    return iqResult.c('query', attributes: queryAttributes);
  }
}
