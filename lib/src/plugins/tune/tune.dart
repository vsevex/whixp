import 'dart:async';

import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/plugins/plugins.dart';
import 'package:whixp/src/stanza/error.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stream/base.dart';

import 'package:xml/xml.dart' as xml;

part 'stanza.dart';

/// Information about tunes is provided by the user and propagated on the
/// network by the user's client. The information container for tune data is a
/// __<tune/>__ element that is qualified by the
/// 'http://jabber.org/protocol/tune' namespace.
///
/// see <https://xmpp.org/extensions/xep-0118.html>
class UserTune extends PluginBase {
  /// Tune information SHOULD be communicated and transported by means of the
  /// Publish-Subscribe (XEP-0060) subset specified in Personal Eventing
  /// Protocol (XEP-0163). Because tune information is not pure presence
  /// information and can change independently of the user's availability, it
  /// SHOULD NOT be provided as an extension to __<presence/>__.
  ///
  /// ### Example:
  /// ```xml
  /// <iq type='set'
  ///     from='vsevex@example.com/14793c64-0f94-11dc-9430-000bcd821bfb'
  ///     id='tunes123'>
  ///   <pubsub xmlns='http://jabber.org/protocol/pubsub'>
  ///     <publish node='http://jabber.org/protocol/tune'>
  ///       <item>
  ///         <tune xmlns='http://jabber.org/protocol/tune'>
  ///           <artist>Some Artist</artist>
  ///           <length>686</length>
  ///           <rating>10</rating>
  ///           <source>cartcurtsongs</source>
  ///           <title>Heart of the Sunrise</title>
  ///           <track>3</track>
  ///         </tune>
  ///       </item>
  ///     </publish>
  ///   </pubsub>
  /// </iq>
  /// ``
  UserTune()
      : super(
          'tune',
          description: 'XEP-0118: User Tune',
          dependencies: <String>{'PEP'},
        );

  PEP? _pep;

  @override
  void pluginInitialize() {
    _pep = base.getPluginInstance<PEP>('PEP');
    if (_pep == null) {
      _pep = PEP();
      base.registerPlugin(_pep!);
    }
  }

  /// Publishes the user's current tune.
  ///
  /// [source] represents the album name, website, or other source of the song.
  /// <br>[rating] is the user's rating of the song (from 1 to 10).
  FutureOr<IQ> publishTune<T>(
    JabberID jid, {
    String? artist,
    int? length,
    int? rating,
    String? source,
    String? title,
    String? track,
    String? uri,
    String? node,
    String? id,
    Form? options,
    FutureOr<T> Function(IQ iq)? callback,
    FutureOr<void> Function(StanzaError error)? failureCallback,
    FutureOr<void> Function()? timeoutCallback,
    int timeout = 5,
  }) {
    final tune = Tune();
    tune['artist'] = artist;
    tune['length'] = length.toString();
    tune['rating'] = rating.toString();
    tune['source'] = source;
    tune['title'] = title;
    tune['track'] = track;
    tune['uri'] = uri;

    return _pep!.publish(
      jid,
      tune,
      node: node,
      id: id,
      options: options,
      callback: callback,
      failureCallback: failureCallback,
      timeoutCallback: timeoutCallback,
      timeout: timeout,
    );
  }

  @override
  void sessionBind(String? jid) {
    final pep = base.getPluginInstance<PEP>('PEP');
    if (pep != null) {
      pep.registerPEP('tune', Tune());
    }
  }

  @override
  void pluginEnd() {
    final disco = base.getPluginInstance<ServiceDiscovery>('disco');
    if (disco != null) {
      disco.removeFeature(Tune().namespace);
    }

    final pep = base.getPluginInstance<PEP>('PEP');
    if (pep != null) {
      pep.removeInterest([Tune().namespace]);
    }
  }
}
