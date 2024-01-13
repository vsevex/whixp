import 'dart:developer';
import 'dart:io';

import 'package:args/args.dart';

import 'package:whixp/whixp.dart';

void main(List<String> arguments) {
  exitCode = 0;
  final parser = ArgParser()
    ..addOption(
      'jabberID',
      abbr: 'j',
      valueHelp: 'vsevex@example.com',
      help: 'The Jabber ID that exists in the server.',
      mandatory: true,
    )
    ..addOption(
      'password',
      abbr: 'p',
      valueHelp: 'passwd',
      help: 'Password for the associated Jabber ID.',
      mandatory: true,
    )
    ..addOption(
      'targetJID',
      abbr: 't',
      valueHelp: 'alyosha@example.com',
      help: 'The JID or the host you want to ping to.',
      mandatory: true,
    )
    ..addOption(
      'host',
      abbr: 'h',
      valueHelp: 'example.com',
      help: 'Host address to connect to.',
    );

  final results = parser.parse(arguments);

  final whixp = Whixp(
    results['jabberID'] as String,
    results['password'] as String,
    host: results['host'] as String?,
    logger: Log(enableWarning: true, enableError: true),
  );
  final ping = Ping();

  whixp.connect();
  whixp.registerPlugin(ping);

  whixp.addEventHandler('sessionStart', (_) async {
    await ping.sendPing(
      JabberID(results['targetJID'] as String),
      callback: (stanza) {
        log('Response from ${stanza['from']} after ping: $stanza');
        exitCode = 0;
      },
      failureCallback: (stanza) {
        log('Failure stanza from the server: $stanza');
        exitCode = 2;
      },
    );
  });
}
