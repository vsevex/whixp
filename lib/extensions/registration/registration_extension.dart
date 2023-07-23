part of '../../src/echo.dart';

/// Implements the XEP-0077 (In-Band Registration) protocol. This extension
/// allows users to register new accounts on an XMPP server directly from the
/// client.
class RegistrationExtension extends Extension {
  /// Creates a new instance of [RegistrationExtension].
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

    /// Initializes required namespaces that will be used on the registration
    /// process, and adds the required feature for the extension to work
    /// correctly.
    super.echo!.addNamespace('REGISTER', 'jabber:iq:register');
    super.echo!.disco.addFeature(ns['REGISTER']!);
  }

  /// Initiates the registration process and sending an IQ stanza with the
  /// necessary registration data to the XMPP server.
  ///
  /// Listens for the response and processes the received data to handle the
  /// registration result.
  ///
  /// * @param resultCallback A callback function that will be invoked when
  /// there is incoming `result` stanza from the server.
  /// * @param errorCallback A callback function that will be invoked when there
  /// is incoming `error` stanza from the server.
  ///
  /// For the proper usage of this method, please refer to the Readme file
  /// associated with the extension folder.
  Future<void> submit({
    FutureOr<void> Function(xml.XmlElement)? resultCallback,
    FutureOr<void> Function(EchoException)? errorCallback,
  }) async {
    final id = echo!.getUniqueId('registration');
    final query = EchoBuilder.iq(attributes: {'type': 'set', 'id': id})
        .c('query', attributes: {'xmlns': ns['REGISTER']!});

    final fields = super.echo!._fields.keys.toList();
    for (int i = 0; i < fields.length; i++) {
      final name = fields[i];
      final value = super.echo!._fields[name];
      query.c(name).t(value!).up();
    }

    final completer = Completer<Either<xml.XmlElement, EchoException>>();

    /// Add system handler for accepting incoming stanzas.
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
      completer: completer,
      name: 'iq',
      id: id,
    );

    /// Send stanza which built using [EchoBuilder.iq] constructor.
    await super.echo!.send(query.nodeTree);

    /// Wait for the answer from `completer`.
    final either = await completer.future;

    return either.fold(
      (stanza) => resultCallback?.call(stanza),
      (exception) => errorCallback?.call(exception),
    );
  }
}
