part of '../../src/echo.dart';

class RegistrationExtension extends Extension {
  RegistrationExtension() : super('registration-extension');

  /// This method is not implemented and will not be affected in the use of this
  /// extension.
  @override
  void changeStatus(EchoStatus status, String? condition) {
    // throw ExtensionException.notImplementedFeature(
    //   'Registration',
    //   'Changing Connection Status',
    // );
  }

  /// Do not manually edit this method. This [Extension] differs from other
  /// extensions. Due the [RegistrationExtension] will not call actual [Echo]
  /// instance.
  @override
  void initialize(Echo echo) {
    super.echo = echo;

    super.echo!.addNamespace('REGISTER', 'jabber:iq:register');
    super.echo!.disco.addFeature(ns['REGISTER']!);
  }

  void submit({
    FutureOr<void> Function(xml.XmlElement)? resultCallback,
    FutureOr<void> Function(EchoException)? errorCallback,
  }) {
    final query = EchoBuilder.iq(attributes: {'type': 'set'})
        .c('query', attributes: {'xmlns': ns['REGISTER']!});

    final fields = super.echo!._fields.keys.toList();
    for (int i = 0; i < fields.length; i++) {
      final name = fields[i];
      final value = super.echo!._fields[name];
      query.c(name).t(value!).up();
    }

    super.echo!._addSystemHandler(
      (stanza) {
        final query = stanza.findAllElements('query');

        if (query.isNotEmpty) {
          for (int i = 0; i < query.first.descendantElements.length; i++) {
            final field = query.first.descendantElements.toList()[i];

            if (field.name.local.toLowerCase() == 'instructions') {
              super.echo!.registrationInstructions = Echotils.getText(field);
            }
            super.echo!._fields[field.name.local.toLowerCase()] =
                Echotils.getText(field);
          }
        }
        return false;
      },
      name: 'iq',
      resultCallback: resultCallback,
      errorCallback: errorCallback,
    );

    super.echo!.sendIQ(element: query.nodeTree!);
  }
}
