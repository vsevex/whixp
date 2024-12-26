import 'dart:async';

import 'package:whixp/src/_static.dart';
import 'package:whixp/src/plugins/plugins.dart';
import 'package:whixp/src/stanza/forwarded.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/src/utils.dart';
import 'package:xml/xml.dart';

part 'stanza.dart';

class Inbox {
  const Inbox();

  /// read here for all the options for the inbox querying
  /// https://esl.github.io/MongooseDocs/latest/open-extensions/inbox/
  static FutureOr<IQ> queryInbox<T>({
    RSMSet? pagination,
    int timeout = 5,
  }) {
    final query = InboxQuery(
      rsm: pagination,
    );

    final iq = IQ(generateID: true)
      ..type = iqTypeSet
      ..payload = query;

    return iq.send(
      timeout: timeout,
    );
  }
}
