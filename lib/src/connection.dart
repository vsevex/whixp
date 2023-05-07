import 'dart:async';
import 'dart:math' as math;

import 'package:echo/src/constants.dart';
import 'package:echo/src/echo.dart';
import 'package:echo/src/log.dart';
import 'package:echo/src/sasl.dart';
import 'package:echo/src/sasl_anon.dart';
import 'package:echo/src/sasl_external.dart';
import 'package:echo/src/sasl_oauthbearer.dart';
import 'package:echo/src/sasl_plain.dart';
import 'package:echo/src/sasl_sha1.dart';
import 'package:echo/src/sasl_sha256.dart';
import 'package:echo/src/sasl_sha384.dart';
import 'package:echo/src/sasl_sha512.dart';
import 'package:echo/src/sasl_xoauth2.dart';
import 'package:echo/src/utils.dart';

import 'package:xml/xml.dart' as xml;

class EchoConnection {
  EchoConnection({
    required this.service,
    this.options = const <String, dynamic>{},
  }) {
    /// The connected JID
    jid = '';

    /// The JIDs domain
    domain = null;

    /// stream:features
    features = null;

    /// SASL
    saslData = {};

    mechanisms = {};

    protocolErrorHandlers = {
      'HTTP': {},
      'websocket': {},
    };

    doAuthentication = false;
    paused = false;

    maxRetries = 5;

    /// Initialize the start point.
    reset();

    /// Call onIdle callback every 1/10th of a second.
    _idleTimeout =
        Timer.periodic(const Duration(milliseconds: 100), (_) => _onIdle);
    registerMechanisms();

    /// Initialize plugins
    for (final k in _connectionPlugins!.keys) {
      _connectionPlugins![k] = _Plugin(() {});
    }
  }

  String service;
  final Map<String, dynamic> options;

  int? _uniqueId;
  int? maxRetries;
  String? jid;
  String? domain;
  String? authcid;
  String? authzid;
  Map<String, dynamic>? features;
  dynamic password;
  Map<String, dynamic>? saslData;
  Map<String, dynamic>? mechanisms;
  Map<String, Map>? protocolErrorHandlers;
  Map<String, _Plugin>? _connectionPlugins;
  bool? authenticated;
  bool? connected;
  bool? disconnecting;
  bool? doAuthentication = true;
  bool? paused;
  bool? restored;
  bool? doBind;
  bool? doSession;
  List? _data;
  List? _requests;
  List? scramKeys;
  List<Handler>? addHandlers;
  List<Handler>? removeHandlers;
  List<Function>? timedHandlers;
  List<Function>? handlers;
  List<Function>? removeTimeds;
  List<Function>? addTimeds;
  Timer? _idleTimeout;
  int? disconnectionTimeout;
  Function(Status, String?, xml.XmlElement?)? connectCallback;
  Function? _saslSuccessHandler;
  Function? _saslFailureHandler;
  Function? _saslChallengeHandler;

  void setProtocol() {
    final protocol = options['protocol'] ?? '';
    if (options['worker'] as bool) {}
  }

  void reset() {
    /// TODO: this._proto.reset();
    doSession = false;
    doBind = false;

    /// handler lists
    timedHandlers = [];
    handlers = [];
    removeTimeds = [];
    removeHandlers = [];
    addTimeds = [];
    addHandlers = [];

    _data = [];
    _requests = [];
    _uniqueId = 0;

    authenticated = false;
    connected = false;
    disconnecting = false;
    restored = false;
  }

  void pause() => paused = true;
  void resume() => paused = false;

  String getUniqueId(dynamic suffix) {
    final uuid = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
        .replaceAllMapped(RegExp('[xy]'), (match) {
      final r = math.Random.secure().nextInt(16);
      final v = match.group(0) == 'x' ? r : (r & 0x3 | 0x8);
      return v.toRadixString(16);
    });

    if (suffix is String || suffix is num) {
      return '$uuid:$suffix';
    } else {
      return uuid;
    }
  }

  void addProtocolErrorHandler(
    String protocol,
    int statusCode,
    void Function() callback,
  ) =>
      protocolErrorHandlers![protocol]![statusCode] = callback;

  void connect({
    required String jid,
    dynamic password,
    void Function(Status, String?, xml.XmlElement?)? callback,
    int? wait,
    int? hold,
    String? route,
    String? authcid,
    int disconnectionTimeout = 3000,
  }) {
    this.jid = jid;
    authzid = Utils().getBareJIDFromJID(jid);
    this.password = password;
    scramKeys = null;
    connectCallback = callback;
    disconnecting = false;
    connected = false;
    authenticated = false;
    restored = false;
    this.disconnectionTimeout = disconnectionTimeout;

    domain = Utils().getDomainFromJID(jid);
    changeConnectStatus(Status.connecting, null, null);
  }

  void attach(
    String jid,
    String sid,
    String rid,
    void Function() callback,
    int wait,
    int hold,
    int wind,
  ) {}
  void restore() {}
  void xmlInput(xml.XmlElement element) {}
  void xmlOutput() {}
  void send() {}
  void flush() {}
  void sendPresence() {}
  void sendIQ() {}
  void _queueData() {}
  void _sendRestart() {}
  void addTimedHandler() {}
  void deleteTimedHandler() {}
  void disconnect() {}
  void doDisconnect() {}
  void _dataRecv() {}
  void connectCb(
    xml.XmlElement element,
    void Function()? callback,
    String raw,
  ) {}
  void sortMechanismsByPriority() {}
  void authenticate() {}
  void _attemptSASLAuth() {}
  void _saslChallengeCb() {}
  void _attemptLegacyAuth() {}
  void _onLegacyAuthIQResult() {}
  void _saslSuccessCb() {}
  void _onStreamFeaturesAfterSASL() {}
  void _establishSession() {}
  void _onSessionResultIQ() {}
  void _saslFailureCb() {}
  void _auth2Cb() {}
  void _addSysTimedHandler() {}
  void _addSysHandler() {}
  void _onDisconnectTimeout() {}

  void _onIdle() {}

  void rawInput(String data) {
    return;
  }

  void rawOutput(String data) {
    return;
  }

  void nextValidRid(num rid) {
    return;
  }

  void registerMechanisms() {
    mechanisms = {};
    final mechanismList = <SASL>[
      SASLAnonymous(),
      SASLExternal(),
      SASLOAuthBearer(),
      SASLXOAuth2(),
      SASLPlain(),
      SASLSHA1(),
      SASLSHA256(),
      SASLSHA384(),
      SASLSHA512(),
    ];
    mechanismList.map((mechanism) => registerSASL(mechanism));
  }

  void registerSASL(SASL mechanism) {
    mechanisms![mechanism.name] = mechanism;
  }

  void changeConnectStatus(
    Status status,
    String? condition,
    xml.XmlElement? element,
  ) {
    for (final k in _connectionPlugins!.keys) {
      final plugin = _connectionPlugins![k];
      if (plugin!.status != status) {
        try {
          plugin.status = status;
        } catch (error) {
          Log().error('$k plugin caused an exception changing status: $error');
        }
      }
    }
    if (connectCallback != null) {
      try {
        connectCallback!.call(status, condition, element);
      } catch (error) {
        Log().error('User connection callback caused an exception: $error');
      }
    }
  }

  Handler addHandler({
    required bool Function(xml.XmlElement) handler,
    required String namespace,
    required String name,
    required String type,
    required String id,
    required String from,
    required Map<String, bool> options,
  }) {
    final hand = Handler(
      handler: handler,
      name: name,
      namespace: namespace,
      type: type,
      id: id,
      from: from,
      options: options,
    );
    addHandlers!.add(hand);
    return hand;
  }

  void deleteHandler(Handler handler) {
    removeHandlers!.add(handler);
    final i = addHandlers!.indexOf(handler);
    if (i >= 0) {
      addHandlers!.removeAt(i);
    }
  }

  void addSysHandler() {}
}

class _Plugin {
  _Plugin(this.init);

  final void Function() init;
  Status? status;
}
