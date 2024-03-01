import 'dart:async';

import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/plugins/plugins.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/features.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stream/base.dart';

import 'package:xml/xml.dart' as xml;

part 'stanza.dart';

class InBandRegistration extends PluginBase {
  InBandRegistration({
    bool createAccount = true,
    bool forceRegistration = false,
    // String formInstructions = 'Enter your credentials',
  }) : super(
          'register',
          description: 'XEP-0077: In-Band Registration',
          dependencies: <String>{'forms'},
        ) {
    _createAccount = createAccount;
    _forceRegistration = forceRegistration;
    // _formInstructions = formInstructions;
  }

  // late final String _formInstructions;
  late final bool _createAccount;
  late final bool _forceRegistration;
  // late final Map<String, Map<String, dynamic>> _users;

  @override
  void pluginInitialize() {
    // if (base.isComponent) {
    //   final disco = base.getPluginInstance<ServiceDiscovery>('disco');
    //   if (disco != null) {
    //     disco.addFeature('jabber:iq:register');
    //   }
    //   _users = <String, Map<String, dynamic>>{};
    //   base.transport.registerHandler(
    //     FutureCallbackHandler(
    //       'registration',
    //       (stanza) => _handleRegistration(stanza as IQ),
    //       matcher: StanzaPathMatcher('/iq/register'),
    //     ),
    //   );
    // } else {
    base.registerFeature(
      'register',
      (_) => _handleRegisterFeature(),
      order: 50,
    );
    // }

    base.addEventHandler('connected', (_) => _forceReg());
  }

  // bool _validateUser(JabberID iqFrom, Register registration) {
  //   _users[iqFrom.bare] = <String, dynamic>{
  //     for (final e in _formFields) e: registration[e],
  //   };

  //   if (_users[iqFrom.bare]!.containsValue(null)) {
  //     return false;
  //   }
  //   return true;
  // }

  // Map<String, dynamic>? _getUser(IQ iq) {
  //   final from = iq['from'] as String;
  //   if (from.isNotEmpty) {
  //     return _users[JabberID(from).bare];
  //   }
  //   return null;
  // }

  // bool _removeUser(IQ iq) {
  //   final from = iq['from'] as String;
  //   if (from.isNotEmpty) {
  //     final result = _users.remove(JabberID(from).bare);
  //     if (result == null) {
  //       return false;
  //     }
  //     return true;
  //   }
  //   throw Exception();
  // }

  void _forceReg() {
    if (_forceRegistration) {
      base.transport.addFilter(filter: _forceStreamFeature);
    }
  }

  StanzaBase _forceStreamFeature(StanzaBase? stanza) {
    if (stanza != null && stanza is StreamFeatures) {
      if (!base.transport.disableStartTLS) {
        if (base.features.contains('starttls')) {
          return stanza;
        } else if (!base.transport.isConnectionSecured) {
          return stanza;
        }
      }
      if (base.features.contains('mechanisms')) {
        Log.instance.debug('Force adding in-band registration stream feature');
        base.transport.removeFilter(filter: _forceStreamFeature);
        stanza.enable('register');
      }
    }
    return stanza!;
  }

  // Future<IQ?> _handleRegistration(IQ iq) async {
  //   if (iq['type'] == 'get') {
  //     return _sendForm(iq);
  //   } else if (iq['type'] == 'set') {
  //     if ((iq['register'] as Register)['remove'] as bool) {
  //       try {
  //         final result = _removeUser(iq);
  //         if (result) {
  //           return Future.value();
  //         } else {
  //           _sendError(iq, 404, 'cancel', 'item-not-found', 'User not found');
  //           return Future.value();
  //         }
  //       } on Exception {
  //         final reply = iq.replyIQ();
  //         reply.sendIQ();
  //         base.transport.emit<IQ>('userUnregister', data: iq);
  //         return Future.value();
  //       }
  //     }

  //     for (final field in _formFields) {
  //       if ((iq['register'] as Register)[field] == null) {
  //         _sendError(
  //           iq,
  //           406,
  //           'modify',
  //           'not-acceptable',
  //           'Please fill in all fields.',
  //         );
  //         return Future.value();
  //       }
  //     }

  //     if (!_validateUser(
  //       JabberID(iq['from'] as String),
  //       iq['register'] as Register,
  //     )) {
  //       _sendError(
  //         iq,
  //         406,
  //         'modify',
  //         'not-acceptable',
  //         'Form attribute can not be null',
  //       );
  //     } else {
  //       final reply = iq.replyIQ();
  //       return reply.sendIQ(
  //         callback: (iq) {
  //           base.transport.emit<IQ>('userRegister', data: iq);
  //         },
  //       );
  //     }
  //   }
  //   return Future.value();
  // }

  Future<bool> _handleRegisterFeature() async {
    if (base.features.contains('mechanisms')) {
      return false;
    }

    print(_createAccount);
    print(base.transport.eventHandled('register'));
    if (_createAccount && base.transport.eventHandled('register') > 0) {
      print('IT SHOULD BRING US REGISTRATION FORM');
      await getRegistration(
        callback: (iq) =>
            base.transport.emit<Form>('register', data: iq['form'] as Form),
      );
    }
    return Future.value(false);
  }

  Future<IQ> getRegistration<T>({
    JabberID? jid,
    JabberID? iqFrom,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 10,
  }) async {
    final iq = base.makeIQGet(iqTo: jid, iqFrom: iqFrom)..enable('register');

    return iq.sendIQ(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  // Future<IQ> _sendForm(IQ iq) async {
  //   final reply = _makeRegistrationForm(iq);
  //   return reply.sendIQ();
  // }

  // IQ _makeRegistrationForm(IQ iq) {
  //   final register = iq['register'] as Register;
  //   Map<String, dynamic>? user = _getUser(iq);

  //   if (user == null) {
  //     user = {};
  //   } else {
  //     register['registered'] = true;
  //   }

  //   register['instructions'] = _formInstructions;

  //   for (final field in _formFields) {
  //     final data = user[field];
  //     if (data != null) {
  //       register[field] = data;
  //     } else {
  //       register._addField(field);
  //     }
  //   }

  //   final reply = iq.replyIQ();
  //   reply.setPayload([register.element!]);
  //   return reply;
  // }

  // void _sendError(IQ iq, int code, String errorType, String name, String text) {
  //   final reply = iq.replyIQ();
  //   reply.setPayload([(iq['register'] as Register).element!]);
  //   reply.error();
  //   final error = reply['error'] as StanzaError;
  //   error['code'] = code.toString();
  //   error['type'] = errorType;
  //   error['condition'] = name;
  //   error['text'] = text;
  //   reply.send();
  // }

  @override
  void sessionBind(String? jid) {}

  @override
  void pluginEnd() => base.unregisterFeature(name, order: 50);
}
