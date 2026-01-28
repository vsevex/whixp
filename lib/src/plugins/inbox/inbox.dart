import 'dart:async';

import 'package:whixp/src/_static.dart';
import 'package:whixp/src/plugins/plugins.dart';
import 'package:whixp/src/stanza/forwarded.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/transport.dart';
import 'package:whixp/src/utils/src/utils.dart';

import 'package:xml/xml.dart';

part 'stanza.dart';

class Inbox {
  const Inbox();

  /// read here for all the options for the inbox querying
  /// https://esl.github.io/MongooseDocs/latest/open-extensions/inbox/
  static FutureOr<IQ> queryInbox<T>(
    Transport transport, {
    RSMSet? pagination,
    int timeout = 5,
  }) {
    final query = InboxQuery(rsm: pagination);

    final iq = IQ(generateID: true)
      // XEP-0430 uses an IQ of type "get" for querying.
      ..type = iqTypeGet
      ..payload = query;

    return iq.send(transport, timeout: timeout);
  }
}
