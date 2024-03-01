part of 'dataforms.dart';

class Form extends XMLBase {
  Form({
    String? title,
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.pluginIterables,
    super.getters,
    super.setters,
    super.deleters,
    super.element,
    super.parent,
  }) : super(
          name: 'x',
          namespace: WhixpUtils.getNamespace('FORMS'),
          pluginAttribute: 'form',
          pluginMultiAttribute: 'forms',
          interfaces: {
            'instructions',
            'reported',
            'title',
            'type',
            'items',
            'values',
          },
          subInterfaces: {'title'},
        ) {
    _title = title;
    if (_title != null) {
      this['title'] = _title;
    }
    addGetters(<Symbol, dynamic Function(dynamic args, XMLBase base)>{
      const Symbol('instructions'): (args, base) => instructions,
      const Symbol('fields'): (args, base) => fields,
    });

    addSetters(
      <Symbol, void Function(dynamic value, dynamic args, XMLBase base)>{
        const Symbol('instructions'): (value, args, base) =>
            setInstructions(value),
      },
    );

    addDeleters(<Symbol, void Function(dynamic args, XMLBase base)>{
      const Symbol('instructions'): (args, base) => deleteInstructions(),
      const Symbol('fields'): (args, base) => deleteFields(),
    });

    registerPlugin(FormField(), iterable: true);
  }

  String? _title;

  /// Whenever there is a need to send form without any additional data, this
  /// static variable can be used.
  static Form defaultConfig = Form();

  @override
  bool setup([xml.XmlElement? element]) {
    final result = super.setup(element);
    if (result) {
      this['type'] = 'form';
    }

    return result;
  }

  void addItem(Map<String, dynamic> values) {
    final itemElement = WhixpUtils.xmlElement('item');
    element!.children.add(itemElement);
    final reportedVariables = reported.keys;
    for (final variable in reportedVariables) {
      final field = FormField();
      field._type = reported[variable]?['type'] as String;
      field['var'] = variable;
      field['value'] = values[variable];
      itemElement.children.add(field.element!);
    }
  }

  void setType(String formType) {
    setAttribute('type', formType);
    if (formType == 'submit') {
      for (final value in fields.entries) {
        final field = fields[value.key]!;
        if (field['type'] != 'hidden') {
          field.delete('type');
        }
        field
          ..delete('label')
          ..delete('desc')
          ..delete('required')
          ..deleteOptions();
      }
    } else if (formType == 'cancel') {
      deleteFields();
    }
  }

  void setValues(Map<String, dynamic> values) {
    final fields = this.fields;
    for (final field in values.entries) {
      if (!this.fields.containsKey(field.key)) {
        fields[field.key] = addField(variable: field.key);
      }
      this.fields[field.key]?['value'] = values[field.key];
    }
  }

  Map<String, FormField> get fields {
    final fields = <String, FormField>{};
    for (final stanza in this['substanzas'] as List<XMLBase>) {
      if (stanza is FormField) {
        fields[stanza['var'] as String] = stanza;
      }
    }

    return fields;
  }

  FormField addField({
    String variable = '',
    String? formType,
    String? label,
    String? description,
    bool? required = false,
    dynamic value,
    List<Map<String, String>>? options,
  }) {
    final field = FormField();
    field['var'] = variable;
    field['type'] = formType;
    field['value'] = value;
    if ({'form', 'result'}.contains(this['type'])) {
      field['label'] = label;
      field['desc'] = description;
      field['required'] = required;
      if (options != null) {
        for (final option in options) {
          field.addOption(
            label: option['label'] ?? '',
            value: option['value'] ?? '',
          );
        }
      }
    } else {
      if (field['type'] != 'hidden') {
        field.delete('type');
      }
    }
    add(field);
    return field;
  }

  void setFields(Map<String, Map<String, dynamic>> fields) {
    delete('fields');
    for (final field in fields.entries) {
      addField(
        variable: field.key,
        label: field.value['label'] as String?,
        description: field.value['desc'] as String?,
        required: field.value['required'] as bool?,
        value: field.value['value'],
        options: field.value['options'] as List<Map<String, String>>?,
        formType: field.value['type'] as String?,
      );
    }
  }

  void deleteFields() {
    final fields = element!.findAllElements('field', namespace: namespace);
    for (final field in fields) {
      element!.children.remove(field);
    }
  }

  String get instructions {
    final instructionsElement =
        element!.getElement('instructions', namespace: namespace);
    if (instructionsElement == null) return '';
    return instructionsElement.children
        .map((element) => element.innerText)
        .join('\n');
  }

  void setInstructions(dynamic instructions) {
    delete('instructions');

    List<String> temp = <String>[];
    if (instructions is String? &&
        (instructions == null || instructions.isEmpty)) {
      return;
    }

    if (instructions is! List) {
      temp = (instructions as String).split('\n');
    }

    for (final instruction in temp) {
      element!.children
          .add(WhixpUtils.xmlElement('instructions')..innerText = instruction);
    }
  }

  void deleteInstructions() {
    final instructions = element!.findAllElements('instructions');
    for (final instruction in instructions) {
      element!.children.remove(instruction);
    }
  }

  Map<String, FormField> getValues() {
    final values = <String, FormField>{};
    final fields = this.fields;
    for (final field in fields.entries) {
      values[field.key] = field.value;
    }
    return values;
  }

  Map<String, FormField> get reported {
    final fields = <String, FormField>{};
    final fieldElement =
        element!.findAllElements('reported', namespace: namespace);
    final reporteds = <xml.XmlElement>[];

    for (final element in fieldElement) {
      final elements = element.findAllElements(
        'field',
        namespace: FormField().namespace,
      );
      for (final element in elements) {
        reporteds.add(element);
      }
    }

    for (final reported in reporteds) {
      final field = FormField(element: reported);
      fields[field['var'] as String] = field;
    }

    return fields;
  }

  FormField addReported(
    String variable, {
    String? formType,
    String label = '',
    String description = '',
  }) {
    xml.XmlElement? reported =
        element!.getElement('reoprted', namespace: namespace);
    if (reported == null) {
      reported = WhixpUtils.xmlElement('reported');
      element!.children.add(reported);
    }
    final fieldElement = WhixpUtils.xmlElement('field');
    reported.children.add(fieldElement);
    final field = FormField(element: fieldElement);
    field['var'] = variable;
    field['type'] = formType;
    field['label'] = label;
    field['desc'] = description;
    return field;
  }

  void setReported(Map<String, Map<String, dynamic>> reported) {
    for (final variable in reported.entries) {
      addReported(
        variable.key,
        formType: variable.value['type'] as String?,
        description: (variable.value['desc'] as String?) ?? '',
        label: (variable.value['label'] as String?) ?? '',
      );
    }
  }

  @override
  Form copy({xml.XmlElement? element, XMLBase? parent}) => Form(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        pluginIterables: pluginIterables,
        title: _title,
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}
