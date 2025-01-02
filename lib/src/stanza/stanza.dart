import 'package:whixp/src/_static.dart';
import 'package:whixp/src/exception.dart';
import 'package:whixp/src/plugins/features.dart';
import 'package:whixp/src/plugins/inbox/inbox.dart';
import 'package:whixp/src/plugins/plugins.dart';
import 'package:whixp/src/plugins/version.dart';
import 'package:whixp/src/stanza/forwarded.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/utils/utils.dart';
import 'package:xml/xml.dart' as xml;

/// This class is the base for all stanza types in `Whixp`.
/// Stanza objects carry the core XML packet structure and metadata.
abstract class Stanza with Packet {
  /// Default constructor for [Stanza] class.
  const Stanza();

  /// Constructs a specific [Stanza] object from an XML element.
  factory Stanza.payloadFromXML(String tag, xml.XmlElement node) {
    if (tag == bindTag) {
      return Bind.fromXML(node);
    } else if (tag == discoInformationTag) {
      return DiscoInformation.fromXML(node);
    } else if (tag == discoItemsTag) {
      return DiscoItems.fromXML(node);
    } else if (tag == versionTag) {
      return Version.fromXML(node);
    } else if (tag == formsTag) {
      return Form.fromXML(node);
    } else if (tag == tuneTag) {
      return Tune.fromXML(node);
    } else if (tag == moodTag) {
      return Mood.fromXML(node);
    } else if (tag == pubsubTag) {
      return PubSubStanza.fromXML(node);
    } else if (tag == pubsubOwnerTag) {
      return PubSubStanza.fromXML(node);
    } else if (tag == pubsubEventTag) {
      return PubSubEvent.fromXML(node);
    } else if (tag == stanzaIDTag) {
      return StanzaID.fromXML(node);
    } else if (tag == originIDTag) {
      return OriginID.fromXML(node);
    } else if (tag == vCard4Tag) {
      return VCard4.fromXML(node);
    } else if (tag == adhocCommandTag) {
      return Command.fromXML(node);
    } else if (tag == enableTag) {
      return Command.fromXML(node);
    } else if (tag == disableTag) {
      return Disable.fromXML(node);
    } else if (tag == delayTag) {
      return DelayStanza.fromXML(node);
    } else if (tag == rsmSetTag) {
      return RSMSet.fromXML(node);
    } else if (tag == mamQueryTag) {
      return MAMQuery.fromXML(node);
    } else if (tag == mamFinTag) {
      return MAMFin.fromXML(node);
    } else if (tag == mamMetadataTag) {
      return MAMMetadata.fromXML(node);
    } else if (tag == mamResultTag) {
      return MAMResult.fromXML(node);
    } else if (tag == forwardedTag) {
      return Forwarded.fromXML(node);
    } else if (tag == inboxQueryTag) {
      return InboxQuery.fromXML(node);
    } else if (tag == inboxFinTag) {
      return InboxFin.fromXML(node);
    } else if (tag == inboxResultTag) {
      return InboxResult.fromXML(node);
    } else {
      throw WhixpInternalException.stanzaNotFound(
        node.localName,
        WhixpUtils.generateNamespacedElement(node),
      );
    }
  }
}

/// This class is the base for all message stanza types.
abstract class MessageStanza extends Stanza {
  const MessageStanza();

  /// Returns the XML tag associated with the [IQStanza] object.
  ///
  /// This tag represents the name of the XML element for the IQ stanza.
  ///
  /// Saves the tag in the given format "{namespace}name".
  String get tag;
}

/// This class is the base for all presence stanza types.
abstract class PresenceStanza extends Stanza {
  /// Returns the XML tag associated with the [IQStanza] object.
  ///
  /// This tag represents the name of the XML element for the IQ stanza.
  ///
  /// Saves the tag in the given format "{namespace}name".
  String get tag;
}

/// This class is the base for all IQ stanza types.
/// IQ stanzas are used to request, query, or command data from a server.
abstract class IQStanza extends Stanza {
  const IQStanza();

  /// Returns the namespace associated with the [IQStanza] object.
  ///
  /// The namespace is a unique identifier for the XML schema used in the
  /// stanza.
  String get namespace;

  /// Returns the XML tag associated with the [IQStanza] object.
  ///
  /// This tag represents the name of the XML element for the IQ stanza.
  ///
  /// Saves the tag in the given format "{namespace}name".
  String get tag;
}
