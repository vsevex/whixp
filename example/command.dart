import 'dart:developer';

import 'package:whixp/whixp.dart';

void main() {
  final whixp = WhixpComponent(
    'push.example.com',
    secret: 'pushnotifications',
    host: 'example.com',
    port: 5275,
    logger: Log(enableError: true, enableWarning: true),
    provideHivePath: true,
  );

  final adhoc = AdHocCommands();
  final forms = DataForms();
  final ping = Ping(interval: 60, keepalive: true);

  whixp
    ..registerPlugin(ServiceDiscovery())
    ..registerPlugin(adhoc)
    ..registerPlugin(forms)
    ..registerPlugin(ping);
  whixp.connect();

  Map<String, dynamic>? handleBroadcastComplete(
    Form payload,
    Map<String, dynamic>? session,
  ) {
    final form = payload;

    final broadcast = form.getValues()['broadcast'];
    log(broadcast.toString());

    if (session != null) {
      session['payload'] = null;
      session['next'] = null;
    }

    return session;
  }

  Map<String, dynamic>? handleBroadcast(
    IQ iq,
    Map<String, dynamic>? session, [
    _,
  ]) {
    final form = forms.createForm(title: 'Broadcast Form');
    form['instructions'] = 'Send a broadcast request to the JID';
    form.addField(
      variable: 'broadcast',
      formType: 'text-single',
      label: 'you want to hangout?',
    );

    if (session != null) {
      session['payload'] = form;
      session['next'] = handleBroadcastComplete(form, session);
      session['hasNext'] = false;
    }

    return session;
  }

  whixp.addEventHandler('sessionStart', (_) {
    adhoc.addCommand(
      node: 'broadcasting',
      name: 'Broadcast',
      handler: handleBroadcast,
    );
  });
}
