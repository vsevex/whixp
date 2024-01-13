part of 'disco.dart';

/// The ability to discover information about entities on the Jabber network is
/// extremely valuable. Such information might include features offered or
/// protocols supported by the entity, the entity's type or identity, and
/// additional entities that are associated with the original entity in some way
/// (often thought of as "children" of the "parent" entity).
///
/// see https://xmpp.org/extensions/xep-0030.html#intro
class DiscoveryInformation extends StanzaConcrete {
  /// Allows for users and agents to find the identities and features supported
  /// by other entities in the network (XMPP) through service discovery
  /// ("disco").
  ///
  /// In particular, the "disco#info" query type of __IQ__ stanzas is used to
  /// request the list of identities and features offered by a Jabber ID.
  ///
  /// An identity is a combination of a __category__ and __type__, such as the
  /// "client" category with a type "bot" to indicate the agent is not a human
  /// operated client, or a category of "gateway" with a type of "aim" to
  /// identify the agent as a gateway for the legacy AIM protocol.
  ///
  /// XMPP Registrar Disco Categories: <http://xmpp.org/registrar/disco-categories.html>
  ///
  /// ### Example:
  /// ```xml
  /// <iq type="result">
  ///   <query xmlns="http://jabber.org/protocol/disco#info">
  ///     <identity category="client" type="bot" name="Slixmpp Bot" />
  ///     <feature var="http://jabber.org/protocol/disco#info" />
  ///     <feature var="jabber:x:data" />
  ///     <feature var="urn:xmpp:ping" />
  ///   </query>
  /// </iq>
  /// ```
  const DiscoveryInformation(super.concrete);

  /// Returns a [Set] or [List] of all identities in [DiscoveryIdentity].
  ///
  /// If a [language] was specified, only return identities using that language.
  /// If [duplicate] was set to true, then use [List] as it is allowed to
  /// duplicate items.
  Iterable<DiscoveryIdentity> getIdentities({
    String? language,
    bool duplicate = false,
  }) =>
      (concrete as DiscoInformationAbstract)
          .getIdentities(language: language, duplicate: duplicate);

  /// Adds a new identity element. Each identity must be unique in terms of all
  /// four identity components.
  ///
  /// The XMPP Registrar maintains a registry of values for the [category] and
  /// [type] attributes of the <identity/> element in the
  /// 'http://jabber.org/protocol/disco#info' namespace.
  ///
  /// Multiple, identical [category]/[type] pairs allowed only if the xml:lang
  /// values are different. Likewise, multiple [category]/[type]/xml:[language]
  /// pairs are allowed so long as the [name]s are different.
  ///
  /// [category] and [type] are required.
  ///
  /// see: <https://xmpp.org/registrar/disco-categories.html>
  bool addIdentity(
    String category,
    String type, {
    String? name,
    String? language,
  }) =>
      (concrete as DiscoInformationAbstract)
          .addIdentity(category, type, name: name, language: language);

  /// Adds or replaces all entities. The [identities] must be in a
  /// [DiscoveryIdentity] form.
  ///
  /// If a [language] is specified, any [identities] using that language will be
  /// removed to be replaced with the given [identities].
  void setIdentities(
    Iterable<DiscoveryIdentity> identities, {
    String? language,
  }) =>
      (concrete as DiscoInformationAbstract)
          .setIdentities(identities, language: language);

  /// Removes a given identity.
  bool deleteIdentity(
    String category,
    String type, {
    String? name,
    String? language,
  }) =>
      (concrete as DiscoInformationAbstract)
          .deleteIdentity(category, type, name: name, language: language);

  /// Removes all identities. If a [language] was specified, only remove
  /// identities using that language.
  void deleteIdentities({String? language}) =>
      (concrete as DiscoInformationAbstract)
          .deleteIdentities(language: language);

  /// Returns a [Set] or [List] of all features as so:
  /// __(category, type, name, language)__
  ///
  /// If [duplicate] was set to true, then use [List] as it is allowed to
  /// duplicate items.
  Iterable<String> getFeatures({bool duplicate = false}) =>
      (concrete as DiscoInformationAbstract).getFeatures(duplicate: duplicate);

  /// Adds a single feature.
  ///
  /// The XMPP Registrar maintains a registry of features for use as values of
  /// the 'var' attribute of the <feature/> element in the
  /// 'http://jabber.org/protocol/disco#info' namespace;
  ///
  /// see <https://xmpp.org/registrar/disco-features.html>
  bool addFeature(String feature) =>
      (concrete as DiscoInformationAbstract).addFeature(feature);

  /// Adds or replaces all supported [features]. The [features]  must be in a
  /// [Set] where each identity is a [String].
  void setFeatures(Iterable<String> features) =>
      (concrete as DiscoInformationAbstract).setFeatures(features);

  /// Deletes a single feature.
  bool deleteFeature(String feature) =>
      (concrete as DiscoInformationAbstract).deleteFeature(feature);

  /// Removes all features.
  void deleteFeatures() =>
      (concrete as DiscoInformationAbstract).deleteFeatures();

  /// Returns the serialized format of the concrete [XMLBase] stanza.
  @override
  String toString() => concrete.toString();
}

@internal
class DiscoInformationAbstract extends XMLBase {
  DiscoInformationAbstract({
    super.element,
    super.parent,
    super.getters,
    super.deleters,
  }) : super(
          name: 'query',
          namespace: WhixpUtils.getNamespace('DISCO_INFO'),
          pluginAttribute: 'disco_info',
          interfaces: {'node', 'features', 'identities'},
          languageInterfaces: {'identities'},
        ) {
    _features = <String>{};
    _identities = <DiscoveryIdentity>{};

    addDeleters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('identities'): (args, base) => deleteIdentities(),
      const Symbol('features'): (args, base) => deleteFeatures(),
    });
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('identities'): (args, base) => getIdentities(),
      const Symbol('features'): (args, base) => getFeatures(),
    });
    addSetters(
      <Symbol, void Function(dynamic value, dynamic args, XMLBase base)>{
        const Symbol('features'): (value, args, base) =>
            setFeatures(value as Iterable<String>),
      },
    );
  }

  /// [Set] of features.
  late final Set<String> _features;

  late final Set<DiscoveryIdentity> _identities;

  Iterable<DiscoveryIdentity> getIdentities({
    String? language,
    bool duplicate = false,
  }) {
    late final Iterable<DiscoveryIdentity> identities;
    if (duplicate) {
      identities = <DiscoveryIdentity>[];
    } else {
      identities = <DiscoveryIdentity>{};
    }

    for (final idElement
        in element!.findAllElements('identity', namespace: namespace)) {
      final xmlLanguage = idElement.getAttribute('xml:lang');
      if (language == null || xmlLanguage == language) {
        final identity = DiscoveryIdentity(
          idElement.getAttribute('category')!,
          idElement.getAttribute('type')!,
          name: idElement.getAttribute('name'),
          language: idElement.getAttribute('xml:lang'),
        );

        if (identities is Set) {
          (identities as Set).add(identity);
        } else {
          (identities as List).add(identity);
        }
      }
    }

    return identities;
  }

  bool addIdentity(
    String category,
    String type, {
    String? name,
    String? language,
  }) {
    final identity = DiscoveryIdentity(category, type, language: language);
    if (!_identities.contains(identity)) {
      _identities.add(identity);
      final idElement = WhixpUtils.xmlElement('identity');
      idElement.setAttribute('category', category);
      idElement.setAttribute('type', type);
      if (language != null && language.isNotEmpty) {
        idElement.setAttribute('xml:lang', language);
      }
      if (name != null && name.isNotEmpty) {
        idElement.setAttribute('name', name);
      }
      element!.children.insert(0, idElement);
      return true;
    }

    return false;
  }

  void setIdentities(
    Iterable<DiscoveryIdentity> identities, {
    String? language,
  }) {
    deleteIdentities(language: language);
    for (final identity in identities) {
      addIdentity(
        identity.category,
        identity.type,
        name: identity.name,
        language: identity.language,
      );
    }
  }

  bool deleteIdentity(
    String category,
    String type, {
    String? name,
    String? language,
  }) {
    final identity =
        DiscoveryIdentity(category, type, name: name, language: language);
    if (_identities.contains(identity)) {
      _identities.remove(identity);
      for (final idElement
          in element!.findAllElements('identity', namespace: namespace)) {
        final id = DiscoveryIdentity(
          idElement.getAttribute('category') ?? '',
          idElement.getAttribute('type') ?? '',
          language: idElement.getAttribute('xml:lang'),
        );

        if (id == identity) {
          element!.children.remove(idElement);
          return true;
        }
      }
    }

    return false;
  }

  void deleteIdentities({String? language}) {
    for (final idElement
        in element!.findAllElements('identity', namespace: namespace)) {
      if (language == null || language.isEmpty) {
        element!.children.remove(idElement);
      } else if (idElement.getAttribute('xml:lang') == language) {
        _identities.remove(
          DiscoveryIdentity(
            idElement.getAttribute('category') ?? '',
            idElement.getAttribute('type') ?? '',
            language: idElement.getAttribute('xml:lang'),
          ),
        );
        element!.children.remove(idElement);
      }
    }
  }

  Iterable<String> getFeatures({bool duplicate = false}) {
    late final Iterable<String> features;
    if (duplicate) {
      features = <String>[];
    } else {
      features = <String>{};
    }

    for (final featureElement
        in element!.findAllElements('feature', namespace: namespace)) {
      if (features is Set) {
        (features as Set).add(featureElement.getAttribute('var'));
      } else {
        (features as List).add(featureElement.getAttribute('var'));
      }
    }

    return features;
  }

  bool addFeature(String feature) {
    if (!_features.contains(feature)) {
      _features.add(feature);
      final featureElement = WhixpUtils.xmlElement('feature');
      featureElement.setAttribute('var', feature);
      element!.children.add(featureElement);
      return true;
    }
    return false;
  }

  void setFeatures(Iterable<String> features) {
    deleteFeatures();
    for (final feature in features) {
      addFeature(feature);
    }
  }

  bool deleteFeature(String feature) {
    if (_features.contains(feature)) {
      _features.remove(feature);
      for (final featureElement
          in element!.findAllElements('feature', namespace: namespace)) {
        element!.children.remove(featureElement);
        return true;
      }
    }

    return false;
  }

  void deleteFeatures() {
    for (final featureElement
        in element!.findAllElements('feature', namespace: namespace)) {
      element!.children.remove(featureElement);
    }
  }

  /// Overrided [copy] method with `setters` and `getters` list copied.
  @override
  DiscoInformationAbstract copy({xml.XmlElement? element, XMLBase? parent}) =>
      DiscoInformationAbstract(
        element: element,
        parent: parent,
        getters: getters,
        deleters: deleters,
      );
}

/// Represents an identity as defined in disco (service discovery) entities.
///
/// It encapsulates information such as [category], [type], [name], and
/// [language] associated with the identity.
class DiscoveryIdentity {
  /// Constructs an Identity instance with the specified [category] and [type].
  /// Optionally includes a [name] and [language] associated with the identity.
  const DiscoveryIdentity(this.category, this.type, {this.name, this.language});

  /// Gets the category of the identity.
  final String category;

  /// Gets the type of the identity.
  final String type;

  /// Gets the optional name associated with the identity. May be `null` if not
  /// provided.
  final String? name;

  /// Gets the optional language associated with the identity. May be null if
  /// not provided.
  final String? language;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveryIdentity &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          type == other.type &&
          name == other.name &&
          language == other.language;

  @override
  int get hashCode =>
      category.hashCode ^ type.hashCode ^ name.hashCode ^ language.hashCode;

  @override
  String toString() =>
      'Discovery Identity (category: $category, type: $type, name: $name, language: $language)';
}
