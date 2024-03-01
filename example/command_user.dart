import 'package:whixp/whixp.dart';

void main() {
  final whixp = Whixp(
    'alyosha@example.com/mobile',
    'passwd',
    host: 'example.com',
    logger: Log(enableError: true, enableWarning: true),
    hivePathName: 'whixpsecondary',
    provideHivePath: true,
  );

  final adhoc = AdHocCommands();
  final forms = DataForms();
  whixp.registerPlugin(ServiceDiscovery());
  whixp.registerPlugin(adhoc);
  whixp.registerPlugin(forms);
  whixp.connect();

  whixp.addEventHandler('streamNegotiated', (_) {
    adhoc.startCommand(
      JabberID('push.example.com'),
      'broadcasting',
      {
        'next': (IQ iq, Map<String, dynamic>? session) {
          final form = forms.createForm(formType: 'submit');
          if (session != null) {
            form.addField(variable: 'broadcast', value: session['broadcast']);
            session['payload'] = form;
            session['next'] = null;
            adhoc.continueCommand(session);
          }

          return session;
        },
      },
    );
  });
}
