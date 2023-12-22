import 'dart:async';

import 'package:echox/src/stream/base.dart';
import 'package:echox/src/stream/matcher/base.dart';
import 'package:echox/src/transport/transport.dart';

abstract class Handler {
  Handler(this.name, {required this.matcher, this.transport});

  final String name;
  Transport? transport;
  BaseMatcher matcher;

  bool match(StanzaBase stanza) => matcher.match(stanza);

  FutureOr<void> run(StanzaBase payload);
}
