import 'package:whixp/src/utils/utils.dart';

const String $errorStanza = 'error';
const String $presence = 'presence';
const String $bind = 'bind';
const String $message = 'message';
const String $handshake = 'handshake';
const String $rosterQuery = 'query';
const String $rosterItem = 'rosterItem';

const String iqTypeError = "error";
const String iqTypeGet = "get";
const String iqTypeResult = "result";
const String iqTypeSet = "set";

const String messageTypeChat = "chat";
const String messageTypeError = "error";
const String messageTypeGroupchat = "groupchat";
const String messageTypeHeadline = "headline";
const String messageTypeNormal = "normal";

const String presenceTypeError = "error";
const String presenceTypeProbe = "probe";
const String presenceTypeSubscribe = "subscribe";
const String presenceTypeSubscribed = "subscribed";
const String presenceTypeUnavailable = "unavailable";
const String presenceTypeUnsubscribe = "unsubscribe";
const String presenceTypeUnsubscribed = "unsubscribed";

const String presenceShowChat = 'chat';
const String presenceShowAway = 'away';
const String presenceShowDnd = 'dnd';
const String presenceShowXa = 'xa';

const String errorAuth = 'auth';
const String errorCancel = 'cancel';
const String errorContinue = 'continue';
const String errorModify = 'modify';
const String errorWait = 'wait';

/// Tags for incoming stanza filtering.
String get discoInformationTag =>
    '{${WhixpUtils.getNamespace('DISCO_INFO')}}query';
String get discoItemsTag => '{${WhixpUtils.getNamespace('DISCO_ITEMS')}}query';
String get bindTag => '{${WhixpUtils.getNamespace('BIND')}}bind';
String get versionTag => '{jabber:iq:version}query';
String get formsTag => '{${WhixpUtils.getNamespace('FORMS')}}x';
String get tuneTag => '{http://jabber.org/protocol/tune}tune';
String get moodTag => '{http://jabber.org/protocol/mood}mood';
String get pubsubTag => '{${WhixpUtils.getNamespace('PUBSUB')}}pubsub';
String get pubsubOwnerTag =>
    '{${WhixpUtils.getNamespace('PUBSUB')}#owner}pubsub';
String get pubsubEventTag =>
    '{${WhixpUtils.getNamespace('PUBSUB')}#event}event';
String get vCard4Tag => '{urn:ietf:params:xml:ns:vcard-4.0}vcard';
String get adhocCommandTag => '{http://jabber.org/protocol/commands}command';
String get enableTag => '{urn:xmpp:push:0}enable';
String get disableTag => '{urn:xmpp:push:0}disable';
String get delayTag => '{urn:xmpp:delay}delay';
String get stanzaIDTag => '{urn:xmpp:sid:0}stanza-id';
String get originIDTag => '{urn:xmpp:sid:0}origin-id';
String get rsmSetTag => '{http://jabber.org/protocol/rsm}set';
String get mamQueryTag => '{urn:xmpp:mam:2}query';
String get mamFinTag => '{urn:xmpp:mam:2}fin';
String get mamResultTag => '{urn:xmpp:mam:2}result';
String get mamMetadataTag => '{urn:xmpp:mam:2}metadata';
String get forwardedTag => '{urn:xmpp:forward:0}forwarded';

/// Inbox (XEP-0430) stanza tags.
String get inboxQueryTag => '{${WhixpUtils.getNamespace('INBOX')}}inbox';
String get inboxFinTag => '{${WhixpUtils.getNamespace('INBOX')}}fin';
String get inboxResultTag => '{${WhixpUtils.getNamespace('INBOX')}}result';

/// Legacy inbox namespace used by some servers (e.g. older MongooseIM).
String get inboxQueryTagLegacy => '{erlang-solutions.com:xmpp:inbox:0}inbox';
String get inboxFinTagLegacy => '{erlang-solutions.com:xmpp:inbox:0}fin';
String get inboxResultTagLegacy => '{erlang-solutions.com:xmpp:inbox:0}result';

Set<String> get presenceTypes => <String>{
      'subscribe',
      'subscribed',
      'unsubscribe',
      'unsubscribed',
    };
