part of 'form.dart';

/// Represents a field that can be used in a form.
class Field {
  /// Default constructor for creating a [Field] object.
  Field({
    this.variable,
    this.label,
    this.description,
    this.required = false,
    this.type,
    List<String>? values,
    List<FieldOption>? options,
  }) {
    this.values = values ?? <String>[];
    this.options = options ?? <FieldOption>[];
  }

  /// The variable associated with the field.
  final String? variable;

  /// The label of the field.
  final String? label;

  /// The description of the field.
  final String? description;

  /// Indicates whether the field is required or not.
  final bool required;

  /// The type of the field.
  final FieldType? type;

  /// A list of possible values for the field.
  List<String> values = [];

  /// A list of options for the field.
  List<FieldOption> options = [];

  /// Factory constructor to create a [Field] object from an XML element.
  factory Field.fromXML(xml.XmlElement node) {
    String? variable;
    String? label;
    FieldType? type;
    String? description;
    final values = <String>[];
    bool required = false;
    final options = <FieldOption>[];

    for (final attribute in node.attributes) {
      switch (attribute.localName) {
        case 'var':
          variable = attribute.value;
        case 'label':
          label = attribute.value;
        case 'type':
          switch (attribute.value) {
            case "boolean":
              type = FieldType.boolean;
            case "fixed":
              type = FieldType.fixed;
            case "hidden":
              type = FieldType.hidden;
            case "jid-multi":
              type = FieldType.jidMulti;
            case "jid-single":
              type = FieldType.jidSingle;
            case "list-multi":
              type = FieldType.listMulti;
            case "list-single":
              type = FieldType.listSingle;
            case "text-multi":
              type = FieldType.textMulti;
            case "text-private":
              type = FieldType.textPrivate;
            case "text-single":
              type = FieldType.textSingle;
          }
      }
    }

    for (final child in node.children.whereType<xml.XmlElement>()) {
      switch (child.localName) {
        case 'desc':
          description = child.innerText;
        case 'value':
          values.add(child.innerText);
        case 'required':
          required = true;
        case 'option':
          options.add(FieldOption.fromXML(child));
      }
    }

    return Field(
      variable: variable,
      label: label,
      description: description,
      required: required,
      type: type,
      values: values,
      options: options,
    );
  }

  /// Converts the [Field] object to an XML element.
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();
    final dictionary = HashMap<String, String>();

    if (variable?.isNotEmpty ?? false) dictionary['var'] = variable!;
    if (label?.isNotEmpty ?? false) dictionary['label'] = label!;
    if (type != null) dictionary['type'] = _enum2String(type!);

    builder.element(
      'field',
      attributes: dictionary,
      nest: () {
        if (description?.isNotEmpty ?? false) {
          builder.element('desc', nest: () => builder.text(description!));
        }
        if (values.isNotEmpty) {
          for (final value in values) {
            builder.element('value', nest: () => builder.text(value));
          }
        }
        if (required) builder.element('required');
      },
    );

    final root = builder.buildDocument().rootElement;

    if (options.isNotEmpty) {
      for (final option in options) {
        root.children.add(option.toXML().copy());
      }
    }

    return root;
  }
}

/// Represents an option for a field.
class FieldOption {
  /// Creates a [FieldOption] with the provided label and value.
  const FieldOption(this.label, this.value);

  /// The label of the option.
  final String? label;

  /// The value of the option.
  final String? value;

  /// Factory constructor to create a [FieldOption] from an XML element.
  factory FieldOption.fromXML(xml.XmlElement node) {
    final label = node.getAttribute('label');
    final value = node.getElement('value')?.innerText;
    return FieldOption(label, value);
  }

  /// Converts the [FieldOption] object to an XML element.
  xml.XmlElement toXML() {
    final dictionary = HashMap<String, String>();

    if (label != null) dictionary['label'] = label!;
    final element = WhixpUtils.xmlElement('option', attributes: dictionary);
    if (value != null) {
      element.children
          .add(xml.XmlElement(xml.XmlName('value'), [], [xml.XmlText(value!)]));
    }

    return element;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldOption &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          value == other.value;

  @override
  int get hashCode => label.hashCode ^ value.hashCode;
}
