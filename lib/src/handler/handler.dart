import 'package:echox/src/stream/base.dart';
import 'package:echox/src/stream/matcher/base.dart';
import 'package:echox/src/transport/transport.dart';

abstract class Handler {
  Handler(
    this.name, {
    this.transport,
    required this.matcher,
    this.payload,
    this.destroy = false,
  });

  final String name;
  Transport? transport;
  BaseMatcher matcher;
  bool destroy;
  StanzaBase? payload;

  bool match(StanzaBase stanza) => matcher.match(stanza);

  void prerun(StanzaBase payload);

  void run(StanzaBase payload);

  bool get checkDelete => destroy;
}
