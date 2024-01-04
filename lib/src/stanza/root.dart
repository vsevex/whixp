part of '../stream/base.dart';

/// Top-level stanza in a Transport.
///
/// Provides a more XMPP specific exception handler than the provided by the
/// generic [StanzaBase] class.
abstract class RootStanza extends StanzaBase {
  RootStanza({
    super.stanzaType,
    super.stanzaTo,
    super.stanzaFrom,
    super.stanzaID,
    super.name,
    super.namespace,
    super.transport,
    super.receive,
    super.interfaces,
    super.subInterfaces,
    super.languageInterfaces,
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
    super.setupOverride,
    super.boolInterfaces,
    super.element,
    super.parent,
  });

  /// Creates and sends an error reply.
  ///
  /// Typically called when an event handler raises an exception. The error's
  /// type and text content are based on the exception object's type and
  /// content.
  @override
  void exception(Exception excp) {}
}
