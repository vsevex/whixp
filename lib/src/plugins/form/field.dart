part of 'dataforms.dart';

class FormField extends StanzaConcrete {
  FormField(super.concrete);

  @override
  FormFieldAbstract get concrete => super.concrete as FormFieldAbstract;

  void setType(String value) => concrete.setType(value);

  List<Map<String, String>> get options => concrete.options;

  void addOption({String label = '', String value = ''}) =>
      concrete.addOption(label: label, value: value);

  void setOptions(List<dynamic> options) => concrete.setOptions(options);

  void deleteOptions() => concrete.deleteOptions();

  bool get required => concrete.required;

  void setRequired(bool required) => concrete.setRequired(required);

  void removeRequired() => concrete.removeRequired();

  String get answer => concrete.answer;

  void setAnswer(String answer) => concrete.setAnswer(answer);

  void setFalse() => concrete.setFalse();

  void setTrue() => concrete.setTrue();

  dynamic value({bool convert = true}) => concrete.value(convert: convert);

  void setValue(dynamic value) => concrete.setValue(value);

  void removeValue() => concrete.removeValue();
}

@internal
class FormFieldAbstract extends XMLBase {
  FormFieldAbstract({
    super.getters,
    super.setters,
    super.deleters,
    super.element,
    super.parent,
  }) : super(
          name: 'field',
          namespace: WhixpUtils.getNamespace('FORMS'),
          includeNamespace: false,
          pluginAttribute: 'field',
          interfaces: {
            'answer',
            'desc',
            'required',
            'value',
            'label',
            'type',
            'var',
          },
          subInterfaces: {'desc'},
        ) {
    addGetters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('answer'): (args, base) => answer,
      const Symbol('options'): (args, base) => options,
      const Symbol('required'): (args, base) => required,
    });

    addSetters(
      <Symbol, void Function(dynamic value, dynamic args, XMLBase base)>{
        const Symbol('type'): (value, args, base) => setType(value as String),
        const Symbol('answer'): (value, args, base) =>
            setAnswer(value as String),
        const Symbol('false'): (value, args, base) => setFalse(),
        const Symbol('options'): (value, args, base) =>
            setOptions(value as List),
        const Symbol('required'): (value, args, base) =>
            setRequired(value as bool),
        const Symbol('true'): (value, args, base) => setTrue(),
        const Symbol('value'): (value, args, base) => setValue(value),
      },
    );

    addDeleters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('options'): (args, base) => deleteOptions(),
      const Symbol('required'): (args, base) => removeRequired(),
      const Symbol('value'): (args, base) => removeValue(),
    });
  }

  String? _type;
  final _optionTypes = <String>{'list-multi', 'list-single'};
  final _trueValues = <dynamic>{true, 'true', '1'};
  final _multivalueTypes = <String>{
    'hidden',
    'jid-multi',
    'list-multi',
    'text-multi',
  };

  @override
  bool setup([xml.XmlElement? element]) {
    final result = super.setup(element);
    if (result) {
      _type = null;
    } else {
      _type = this['type'] as String;
    }

    return result;
  }

  void setType(String value) {
    setAttribute('type', value);
    if (value.isNotEmpty) {
      _type = value;
    }
  }

  List<Map<String, String>> get options {
    final options = <Map<String, String>>[];

    final optionsElement =
        element!.findAllElements('option', namespace: namespace);
    for (final option in optionsElement) {
      final opt = FieldOption(element: option);
      options.add({
        'label': opt['label'] as String,
        'value': opt['value'] as String,
      });
    }
    return options;
  }

  void addOption({String label = '', String value = ''}) {
    if (_type == null || _optionTypes.contains(_type)) {
      final option = FieldOption();
      option['label'] = label;
      option['value'] = value;
      add(Tuple2(null, option));
    } else {
      Log.instance.warning('Cannot add options to ${this['type']} field.');
    }
  }

  void setOptions(List<dynamic> options) {
    for (final value in options) {
      if (value is Map<String, String>) {
        addOption(value: value['value']!, label: value['label']!);
      } else {
        addOption(value: value as String);
      }
    }
  }

  void deleteOptions() {
    final options = element!.findAllElements('option', namespace: namespace);
    for (final option in options) {
      element!.children.remove(option);
    }
  }

  bool get required {
    final requiredElement =
        element!.getElement('required', namespace: namespace);
    return requiredElement != null;
  }

  void setRequired(bool required) {
    final exists = this['required'] as bool;
    if (!exists && required) {
      element!.children.add(WhixpUtils.xmlElement('required'));
    } else if (exists && !required) {
      delete('required');
    }
  }

  void removeRequired() {
    final required = element!.getElement('required', namespace: namespace);
    if (required != null) {
      element!.children.remove(required);
    }
  }

  String get answer => this['value'] as String;

  void setAnswer(String answer) => this['value'] = answer;

  void setFalse() => this['value'] = false;

  void setTrue() => this['value'] = true;

  dynamic value({bool convert = true}) {
    final values = element!.findAllElements('value', namespace: namespace);
    if (values.isEmpty) {
      return null;
    } else if (_type == 'boolean') {
      if (convert) {
        return _trueValues.contains(values.first.innerText);
      }
      return values.first.innerText;
    } else if (_multivalueTypes.contains(_type) || values.length > 1) {
      dynamic vals = <String>[];
      for (final value in values) {
        (vals as List<String>).add(value.innerText);
      }
      if (_type == 'text-multi' && convert) {
        vals = values.join('\n');
      }
      return vals;
    } else {
      if (values.first.innerText.isEmpty) {
        return '';
      }
      return values.first.innerText;
    }
  }

  void setValue(dynamic value) {
    delete('value');

    if (_type == 'boolean') {
      if (_trueValues.contains(value)) {
        final valueElement = WhixpUtils.xmlElement('value');
        valueElement.innerText = '1';
        element!.children.add(valueElement);
      } else {
        final valueElement = WhixpUtils.xmlElement('value');
        valueElement.innerText = '0';
        element!.children.add(valueElement);
      }
    } else if (_multivalueTypes.contains(_type) ||
        (_type == null || _type!.isEmpty)) {
      dynamic val = value;
      if (val is bool) {
        val = [val];
      }
      if (val is! List) {
        val = (val as String).replaceAll('\r', '');
        val = val.split('\n');
      }
      for (final value in val as List<String>) {
        String val = value;
        if ((_type == null || _type!.isEmpty) && _trueValues.contains(value)) {
          val = '1';
        }
        final valueElement = WhixpUtils.xmlElement('value');
        valueElement.innerText = val;
        element!.children.add(valueElement);
      }
    } else {
      if (value is List) {
        Log.instance
            .warning('Cannot add multiple values to a ${this['type']} field.');
      }
      element!.children
          .add(WhixpUtils.xmlElement('value')..innerText = value as String);
    }
  }

  void removeValue() {
    final value = element!.findAllElements('value', namespace: namespace);
    if (value.isNotEmpty) {
      for (final val in value) {
        element!.children.remove(val);
      }
    }
  }

  @override
  FormFieldAbstract copy({xml.XmlElement? element, XMLBase? parent}) =>
      FormFieldAbstract(
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}

@internal
class FieldOption extends XMLBase {
  FieldOption({super.element, super.parent})
      : super(
          name: 'option',
          namespace: WhixpUtils.getNamespace('FORMS'),
          includeNamespace: false,
          pluginAttribute: 'option',
          interfaces: {'label', 'value'},
          subInterfaces: {'value'},
          pluginMultiAttribute: 'options',
        );

  @override
  FieldOption copy({xml.XmlElement? element, XMLBase? parent}) => FieldOption(
        element: element,
        parent: parent,
      );
}
