import 'package:whixp/src/exception.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stream/base.dart';

/// Top-level stanza in a Transport.
///
/// Provides a more XMPP specific exception handler than the provided by the
/// generic [StanzaBase] class.
abstract class RootStanza extends StanzaBase {
  /// All parameters are extended from [StanzaBase]. For more information please
  /// take a look at [StanzaBase].
  RootStanza({
    super.stanzaType,
    super.stanzaTo,
    super.stanzaFrom,
    super.stanzaID,
    super.name,
    super.namespace,
    super.transport,
    super.interfaces,
    super.subInterfaces,
    super.languageInterfaces,
    super.receive,
    super.includeNamespace = true,
    super.types,
    super.getters,
    super.setters,
    super.deleters,
    super.pluginAttribute,
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.pluginMultiAttribute,
    super.pluginIterables,
    super.overrides,
    super.isExtension,
    super.boolInterfaces,
    super.element,
    super.parent,
  });

  /// Create and send an error reply.
  ///
  /// Typically called when an event handler raises an exception.
  ///
  /// The error's type and text content are based on the exception object's
  /// type and content.
  @override
  void exception(dynamic excp) {
    if (excp is StanzaException) {
      if (excp.message == 'IQ error has occured') {
        final stanza = (this as IQ).replyIQ();
        stanza.transport = transport;
        final error = stanza['error'] as XMLBase;
        error['condition'] = 'undefined-condition';
        error['text'] = 'External error';
        error['type'] = 'cancel';
        stanza.send();
      } else if (excp.condition == 'remote-server-timeout') {
        final stanza = reply(copiedStanza: copy());
        stanza.enable('error');
        final error = stanza['error'] as XMLBase;
        error['condition'] = 'remote-server-timeout';
        error['type'] = 'wait';
        stanza.send();
      } else {
        final id = this['id'];
        final stanza = reply(copiedStanza: copy());
        stanza.enable('error');
        stanza['id'] = id;
        final error = stanza['error'] as XMLBase;
        error['condition'] = 'undefined-condition';
        error['text'] = 'Whixp error occured';
        error['type'] = 'cancel';
        stanza.send();
      }
    }
  }
}
