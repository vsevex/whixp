import 'dart:collection';

import 'package:whixp/src/_static.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

part 'field.dart';

const String _namespace = 'jabber:x:data';
const String _name = 'x';

/// * `form` The form-processing entity is asking the form-submitting entity to
/// complete a form.
/// * `submit` The form-submitting entity is submitting data to the
/// form-processing entity. The submission MAY include fields that were not
/// provided in the empty form, but the form-processing entity MUST ignore any
/// fields that it does not understand. Furthermore, the submission MAY omit
/// fields not marked with required by the form-processing entity.
/// * `cancel` The form-submitting entity has cancelled submission of data to
/// the form-processing entity.
/// * `result` The form-processing entity is returning data (e.g., search
/// results) to the form-submitting entity, or the data is a generic data set.
enum FormType { form, submit, cancel, result }

/// * `boolean`	The field enables an entity to gather or provide an either-or
/// choice between two options. The default value is "false".
/// * `fixed`	The field is intended for data description (e.g., human-readable
/// text such as "section" headers) rather than data gathering or provision. The
/// value child SHOULD NOT contain newlines (the \n and \r characters);
/// instead an application SHOULD generate multiple fixed fields, each with one value child.
/// * `hidden` The field is not shown to the form-submitting entity, but
/// instead is returned with the form. The form-submitting entity SHOULD NOT
/// modify the value of a hidden field, but MAY do so if such behavior is
/// defined for the "using protocol".
/// * `jid-multi`	The field enables an entity to gather or provide multiple
/// Jabber IDs. Each provided JID SHOULD be unique (as determined by comparison
/// that includes application of the Nodeprep, Nameprep, and Resourceprep
/// profiles of Stringprep as specified in XMPP Core), and duplicate JIDs MUST
/// be ignored.
/// * `jid-single` The field enables an entity to gather or provide a single
/// Jabber ID.
/// * `list-multi` The field enables an entity to gather or provide one or
/// more options from among many. A form-submitting entity chooses one or more
/// items from among the options presented by the form-processing entity and
/// MUST NOT insert new options. The form-submitting entity MUST NOT modify the
/// order of items as received from the form-processing entity, since the order
/// of items MAY be significant.
/// * `list-single`	The field enables an entity to gather or provide one option
/// from among many. A form-submitting entity chooses one item from among the
/// options presented by the form-processing entity and MUST NOT insert new
/// options.
/// * `text-multi` The field enables an entity to gather or provide multiple
/// lines of text.
/// * `text-private` The field enables an entity to gather or provide a single
/// line or word of text, which shall be obscured in an interface (e.g., with
/// multiple instances of the asterisk character).
/// * `text-single`	The field enables an entity to gather or provide a single
/// line or word of text, which may be shown in an interface. This field type is
/// the default and MUST be assumed if a form-submitting entity receives a field
/// type it does not understand.
enum FieldType {
  boolean,
  fixed,
  hidden,
  jidMulti,
  jidSingle,
  listMulti,
  listSingle,
  textMulti,
  textPrivate,
  textSingle,
}

/// Converts a [FieldType] enum value to a string representation.
String _enum2String(FieldType type) {
  switch (type) {
    case FieldType.jidMulti:
      return 'jid-multi';
    case FieldType.jidSingle:
      return 'jid-single';
    case FieldType.listMulti:
      return 'list-multi';
    case FieldType.listSingle:
      return 'list-single';
    case FieldType.textMulti:
      return 'text-multi';
    case FieldType.textPrivate:
      return 'text-private';
    case FieldType.textSingle:
      return 'text-single';
    default:
      return type.name;
  }
}

/// Represents a form.
class Form extends MessageStanza {
  /// Default constructor for creating a [Form] object.
  Form({
    this.instructions,
    this.title,
    this.type = FormType.form,
    this.reported,
    List<Field>? fields,
  }) {
    this.fields = fields ?? <Field>[];
  }

  /// Instructions for filling out the form.
  final String? instructions;

  /// Title of the form.
  final String? title;

  /// Type of the form.
  FormType type;

  /// The reported field of the form.
  final Field? reported;

  /// List of fields in the form.
  List<Field> fields = <Field>[];

  /// Factory constructor to create a [Form] object from an XML element.
  factory Form.fromXML(xml.XmlElement node) {
    late FormType type;
    String? instructions;
    String? title;
    final fields = <Field>[];
    Field? reported;

    for (final attribute in node.attributes) {
      if (attribute.localName == 'type') {
        switch (attribute.value) {
          case 'result':
            type = FormType.result;
          case 'submit':
            type = FormType.submit;
          case 'cancel':
            type = FormType.cancel;
          default:
            type = FormType.form;
        }
      }
    }

    for (final child in node.children.whereType<xml.XmlElement>()) {
      if (child.localName == 'instructions') {
        instructions = child.innerText;
      }
      if (child.localName == 'title') {
        title = child.innerText;
      }
      if (child.localName == 'field') {
        fields.add(Field.fromXML(child));
      }
      if (child.localName == 'reported') {
        for (final node in child.children.whereType<xml.XmlElement>()) {
          reported = Field.fromXML(node);
        }
      }
      if (child.localName == 'item') {
        for (final node in child.children.whereType<xml.XmlElement>()) {
          fields.add(Field.fromXML(node));
        }
      }
    }

    return Form(
      type: type,
      instructions: instructions,
      title: title,
      reported: reported,
      fields: fields,
    );
  }

  /// Sets the specified [value] to the given [variable].
  void setFieldValue(String variable, dynamic value) {
    for (final field in fields) {
      if (field.variable == variable) {
        field.values = [value.toString()];
      }
    }
  }

  /// Converts the [Form] object to an XML element.
  @override
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();
    final dictionary = HashMap<String, String>();
    dictionary['xmlns'] = _namespace;
    dictionary['type'] = type.name;

    builder.element(
      _name,
      attributes: dictionary,
      nest: () {
        if (instructions?.isNotEmpty ?? false) {
          builder.element(
            'instructions',
            nest: () => builder.text(instructions!),
          );
        }
      },
    );

    final root = builder.buildDocument().rootElement;
    for (final field in fields) {
      root.children.add(field.toXML().copy());
    }

    if (reported != null) {
      final element = WhixpUtils.xmlElement('reported');
      element.children.add(reported!.toXML().copy());
      root.children.add(element);
    }

    return root;
  }

  /// Adds a list of fields to the form.
  void addFields(List<Field> fields) => this.fields.addAll(fields);

  /// Clears all fields from the form.
  void clearFields() => fields.clear();

  @override
  String get name => 'dataforms';

  @override
  String get tag => formsTag;
}
