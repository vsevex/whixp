import 'package:echo/src/builder.dart';
import 'package:echo/src/connection.dart';
import 'package:echo/src/constants.dart';
import 'package:echo/src/log.dart';

import 'package:xml/xml.dart' as xml;

class Websocket {
  /// Factory method which returns private instance of this class.
  factory Websocket() => _instance;

  /// Constant instance of private constructor.
  static final Websocket _instance = Websocket._();

  EchoConnection? connection;

  /// Private constructor of the class.
  Websocket._() {
    final service = connection!.service;
    if (service.indexOf('ws:') != 0 && service.indexOf('wss:') != 0) {
      String newService = '';
      if (connection!.options['protocol'] == 'ws') {
        newService += 'ws';
      } else {
        newService += 'wss';
      }
      newService += '://${Uri.base.host}';
      if (newService.indexOf('/') != 0) {
        newService += Uri.base.path + service;
      } else {
        newService += service;
      }
      connection!.service = newService;
    }
  }

  EchoBuilder buildStream() => EchoBuilder('open', {
        'xmlns': ns['FRAMING']!,
        'to': connection!.domain!,
        'version': '1.0',
      });

  bool checkStreamError(xml.XmlDocument bodyWrap, Status status) {
    xml.XmlElement? errors;
    errors = bodyWrap.getElement('stream:error');
    if (errors == null) return false;

    final error = errors.firstChild;

    String condition = '';
    String text = '';

    const nS = "urn:ietf:params:xml:ns:xmpp-streams";
    for (final e in error!.children) {
      if (e.getAttribute('xmlns') != nS) {
        break;
      }
      if (e.lastElementChild!.localName == 'text') {
        text = e.innerText;
      } else {
        condition = e.lastElementChild!.localName;
      }
    }

    String errorString = 'Websocket stream error: ';
    if (condition.isNotEmpty) {
      errorString += condition;
    } else {
      errorString += 'unknown';
    }
    if (text.isNotEmpty) {
      errorString += ' - $text';
    }

    Log().error(errorString);

    connection!.changeConnectStatus(status, condition, null);
    connection!.doDisconnect();

    return true;
  }

  void reset() {
    return;
  }

  void connect() {}

  int connectDB(xml.XmlDocument bodyWrap) {
    final error = checkStreamError(bodyWrap, Status.connfail);
    if (error) return status[Status.connfail]!;
    return status[Status.connected]!;
  }

  bool handleStreamStart(xml.XmlNode message) {
    String? error;
    final nS = message.getAttribute('xmlns');

    if (ns is String) {
      error = 'Missing xmlns in <open />';
    } else if (nS != ns['FRAMING']) {
      error = 'Wrong xmlns in <open />: $nS';
    }

    final version = message.getAttribute('version');
    if (version is String) {
      error = 'Missing xmlns in <open />';
    } else if (version != '1.0') {
      error = 'Wrong version in <open />: $version';
    }

    if (error != null) {
      connection!.changeConnectStatus(Status.connfail, error, null);
      connection!.doDisconnect();
      return false;
    }
    return true;
  }

  void _onInitialMessage(String message) {
    if (message.startsWith('<open') || message.startsWith('<?xml')) {
      final data = message.replaceAll(RegExp(r'^(<\?.*?\?>\s*)*'), '');
      if (data.isEmpty) return;

      final streamStart = xml.XmlDocument.parse(data);
      connection!.xmlInput(streamStart.rootElement);
      connection!.rawInput(message);
      if (handleStreamStart(streamStart)) {
        connectDB(streamStart);
      }
    } else if (message.startsWith('<close')) {
      final parsed = xml.XmlDocument.parse(message);
      connection!.xmlInput(parsed.rootElement);
      connection!.rawInput(message);

      final see = parsed.getAttribute('see-other-uri');
      if (see != null) {
        final service = connection!.service;
        final isSecureRedirect =
            (service.contains('wss:') && see.contains('wss:')) ||
                service.contains('ws:');

        if (isSecureRedirect) {
          connection!.changeConnectStatus(
            Status.redirect,
            'Received see-other-uri, resetting connection',
            null,
          );
          connection!.reset();
          connection!.service = see;
          connect();
        }
      } else {
        connection!.changeConnectStatus(
          Status.connfail,
          'Received closing stream',
          null,
        );
        connection!.doDisconnect();
      }
    } else {
      _replaceMessageHandler();
      final string = _streamWrap(message);
      final element = xml.XmlDocument.parse(string);
      connection!.connectCb(element.rootElement, null, message);
    }
  }

  void disconnect(xml.XmlElement presence) {
    if ()
  }

  String _streamWrap(String stanza) => '<wrapper>$stanza</wrapper>';

  void _replaceMessageHandler() => onMessage = (message) => _onMessage(message);

  void _onMessage(String message) {
    xml.XmlDocument element;

    /// Check for closing stream
    const close = '<close xmlns="urn:ietf:params:xml:ns:xmpp-framing" />';
    if (message == close) {
      return;
    } else if (message.startsWith('<open ')) {
      element = xml.XmlDocument.parse(message);
      if (handleStreamStart(element)) {
        return;
      }
    } else {
      final data = _streamWrap(message);
      element = xml.XmlDocument.parse(data);
    }

    if (checkStreamError(element, Status.error)) {
      return;
    }

    /// TODO: handle unavailable presence stanza
  }

  void _onOpen() {
    Log().info('Websocket open');
    final start = buildStream();
    final startString = start.toString();
  }

  xml.XmlElement reqToData(xml.XmlElement stanza) => stanza;
}
