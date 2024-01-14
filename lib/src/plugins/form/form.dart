part of 'dataforms.dart';

class Form extends StanzaConcrete {
  Form(super.concrete);

  @override
  FormAbstract get concrete => super.concrete as FormAbstract;

  void addItem(Map<String, dynamic> values) => concrete.addItem(values);

  void setType(String formType) => concrete.setType(formType);

  void setValues(Map<String, dynamic> values) => concrete.setValues(values);

  Map<String, FormFieldAbstract> get fields => concrete.fields;

  Form addField({
    String variable = '',
    String? formType,
    String? label,
    String? description,
    bool? required = false,
    String? value,
    List<Map<String, String>>? options,
  }) =>
      Form(
        concrete.addField(
          variable: variable,
          formType: formType,
          label: label,
          description: description,
          required: required,
          value: value,
          options: options,
        ),
      );

  void setFields(Map<String, Map<String, dynamic>> fields) =>
      concrete.setFields(fields);

  void deleteFields() => concrete.deleteFields();

  String get instructions => concrete.instructions;

  void setInstructions(dynamic instructions) =>
      concrete.setInstructions(instructions);

  void deleteInstructions() => concrete.deleteInstructions();

  Map<String, Form> get reported =>
      concrete.reported.map((key, value) => MapEntry(key, Form(value)));

  Form addReported(
    String variable, {
    String? formType,
    String label = '',
    String description = '',
  }) =>
      Form(
        concrete.addReported(
          variable,
          formType: formType,
          label: label,
          description: description,
        ),
      );

  void setReported(Map<String, Map<String, dynamic>> reported) =>
      concrete.setReported(reported);
}

@internal
class FormAbstract extends XMLBase {
  FormAbstract({
    String? title,
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
    addGetters(<Symbol, void Function(dynamic args, XMLBase base)>{
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
  }

  String? _title;

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
      final field = FormFieldAbstract();
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
      this.fields[field.key]!['value'] = values[field.key];
    }
  }

  Map<String, FormFieldAbstract> get fields {
    final fields = <String, FormFieldAbstract>{};
    for (final stanza in this['substanzas'] as List<XMLBase>) {
      if (stanza is FormFieldAbstract) {
        fields[stanza['var'] as String] = stanza;
      }
    }

    return fields;
  }

  FormFieldAbstract addField({
    String variable = '',
    String? formType,
    String? label,
    String? description,
    bool? required = false,
    String? value,
    List<Map<String, String>>? options,
  }) {
    final field = FormFieldAbstract();
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
    add(Tuple2(null, field));
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
        value: field.value['value'] as String?,
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

  Map<String, FormFieldAbstract> get reported {
    final fields = <String, FormFieldAbstract>{};
    final fieldElement =
        element!.findAllElements('reported', namespace: namespace);
    final reporteds = <xml.XmlElement>[];

    for (final element in fieldElement) {
      final elements = element.findAllElements(
        'field',
        namespace: FormFieldAbstract().namespace,
      );
      for (final element in elements) {
        reporteds.add(element);
      }
    }

    for (final reported in reporteds) {
      final field = FormFieldAbstract(element: reported);
      fields[field['var'] as String] = field;
    }

    return fields;
  }

  FormFieldAbstract addReported(
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
    final field = FormFieldAbstract(element: fieldElement);
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
  FormAbstract copy({xml.XmlElement? element, XMLBase? parent}) => FormAbstract(
        title: _title,
        getters: getters,
        setters: setters,
        deleters: deleters,
        element: element,
        parent: parent,
      );
}
