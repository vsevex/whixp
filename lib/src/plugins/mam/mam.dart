import 'dart:async' as async;

import 'package:whixp/src/_static.dart';
import 'package:whixp/src/plugins/plugins.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/forwarded.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/node.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

part 'stanza.dart';

class MAM {
  const MAM();

  /// An entity is able to query (subject to appropriate access rights) an
  /// archive for all messages within a certain timespan, optionally restricting
  /// results to those to/from a particular JID.
  ///
  /// The final <iq/> result response MUST include an RSM <set/> element,
  /// wrapped into a <fin/> element qualified by the 'urn:xmpp:mam:2' namespace,
  /// indicating the UID of the first and last message of the (possibly limited)
  /// result set. This allows clients to accurately page through messages.
  static async.FutureOr<IQ> queryArchive<T>({
    Form? filter,
    RSMSet? pagination,
    async.FutureOr<T> Function(IQ result)? callback,
    async.FutureOr<void> Function(ErrorStanza error)? failureCallback,
    async.FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final query = MAMQuery(form: filter, rsm: pagination);

    final iq = IQ(generateID: true)
      ..type = iqTypeSet
      ..payload = query;

    return iq.send(
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  /// Retrieves the current state of the archive. This includes information
  /// about the first/last entries in the archive.
  ///
  /// See more in [MAMMetadata].
  static async.FutureOr<IQ> retrieveMetadata<T>({
    async.FutureOr<T> Function(IQ result)? callback,
    async.FutureOr<void> Function(ErrorStanza error)? failureCallback,
    async.FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) =>
      IQ(generateID: true)
        ..payload = const MAMMetadata()
        ..type = iqTypeGet
        ..send(
          callback: callback,
          failureCallback: failureCallback,
          timeoutCallback: timeoutCallback,
          timeout: timeout,
        );

  /// By default all messages match a query, and filters are used to request a
  /// subset of the archived messages. The hidden FORM_TYPE field MUST be set to
  /// this protocol's namespace, 'urn:xmpp:mam:2'.
  ///
  /// To allow querying for messages the user sent to themselves, the client
  /// needs to set the [wth] attribute to the account JID. In that case, the
  /// server MUST only return results where both the 'to' and 'from' match the
  /// bare JID (either as bare or by ignoring the resource), as otherwise every
  /// message in the archive would match.
  ///
  /// If the server advertises that it includes groupchat messages in a user's
  /// archive, you may query a user archive and request for them to be included.
  ///
  /// Note: [wth] corresponds to the word of 'with'. Dart uses this word as a
  /// keyword.
  Form createFilter({
    String? start,
    String? end,
    String? wth,
    String? beforeID,
    String? afterID,
    List<String>? ids,
    bool includeGroupchats = false,
  }) {
    final fields = <Field>[];

    if (start?.isNotEmpty ?? false) {
      fields.add(Field(variable: 'start', values: [start!]));
    }

    if (end?.isNotEmpty ?? false) {
      fields.add(Field(variable: 'end', values: [end!]));
    }

    if (wth?.isNotEmpty ?? false) {
      fields.add(Field(variable: 'with', values: [wth!]));
    }

    if (beforeID?.isNotEmpty ?? false) {
      fields.add(Field(variable: 'before-id', values: [beforeID!]));
    }

    if (afterID?.isNotEmpty ?? false) {
      fields.add(Field(variable: 'after-id', values: [afterID!]));
    }

    if (ids?.isNotEmpty ?? false) {
      fields.add(Field(variable: 'ids', values: ids));
    }

    if (includeGroupchats) {
      fields.add(
        Field(
          variable: 'include-groupchat',
          values: [includeGroupchats.toString()],
        ),
      );
    }

    return Form(type: FormType.submit)
      ..addFields([
        Field(type: FieldType.hidden, values: [WhixpUtils.getNamespace('MAM')]),
        ...fields,
      ]);
  }
}
