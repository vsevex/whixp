import 'package:echo/echo.dart';
import 'package:xml/xml.dart' as xml;

abstract class Protocol {
  String? strip;

  void reset();
  void connect();
  void disconnect([xml.XmlElement? presence]);
  void doDisconnect();
  void send();
  void abortAllRequests();
  int connectCB(xml.XmlElement bodyWrap);
  void nonAuth([void Function(Echo)? function]);
  void onIdle();
  xml.XmlElement? reqToData(xml.XmlElement? stanza);
  void sendRestart();
}
