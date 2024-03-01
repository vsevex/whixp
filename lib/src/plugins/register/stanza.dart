part of 'register.dart';

class Register extends XMLBase {
  Register({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.getters,
    super.setters,
    super.deleters,
    super.element,
    super.parent,
  }) : super(
          name: 'query',
          namespace: 'jabber:iq:register',
          pluginAttribute: 'register',
          interfaces: _interfaces,
          subInterfaces: _interfaces,
        ) {
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('registered'): (args, base) => isRegistered,
      const Symbol('remove'): (args, base) => isRemoved,
      const Symbol('fields'): (args, base) => fields,
    });

    addSetters(<Symbol,
        dynamic Function(dynamic value, dynamic args, XMLBase base)>{
      const Symbol('fields'): (value, args, base) =>
          setFields(value as Set<String>),
    });

    addDeleters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('fields'): (args, base) => deleteFields(),
    });

    registerPlugin(Form());
  }

  bool get isRegistered {
    final present = element!.getElement('registered', namespace: namespace);
    return present != null;
  }

  void setRegistered(bool value) {
    if (value) {
      return _addField('remove');
    }
    return delete('remove');
  }

  bool get isRemoved {
    final remove = element!.getElement('remove', namespace: namespace);
    return remove != null;
  }

  void _addField(String value) => setSubText(value, text: '', keep: true);

  Set<String> get fields {
    final fields = <String>{};
    for (final field in _formFields) {
      if (element!.getElement(field, namespace: namespace) != null) {
        fields.add(field);
      }
    }

    return fields;
  }

  void setFields(Set<String> fields) {
    delete('fields');
    for (final field in fields) {
      setSubText(field, text: '', keep: true);
    }
  }

  void deleteFields() {
    for (final field in _formFields) {
      deleteSub(field);
    }
  }

  @override
  Register copy({xml.XmlElement? element, XMLBase? parent}) => Register(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}

class RegisterFeature extends XMLBase {
  RegisterFeature({super.element, super.parent})
      : super(
          name: 'register',
          namespace: 'http://jabber.org/features/iq-register',
          pluginAttribute: 'register',
          interfaces: <String>{},
        );

  @override
  RegisterFeature copy({xml.XmlElement? element, XMLBase? parent}) =>
      RegisterFeature(element: element, parent: parent);
}

const _formFields = <String>{
  'username',
  'password',
  'email',
  'nick',
  'name',
  'first',
  'last',
  'address',
  'city',
  'state',
  'zip',
  'phone',
  'url',
  'date',
  'misc',
  'text',
  'key',
};

const _interfaces = <String>{
  'username',
  'password',
  'email',
  'nick',
  'name',
  'first',
  'last',
  'address',
  'city',
  'state',
  'zip',
  'phone',
  'url',
  'date',
  'misc',
  'text',
  'key',
  'registered',
  'remove',
  'instructions',
  'fields',
};
