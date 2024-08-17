import 'package:whixp/src/plugins/bind.dart';
import 'package:whixp/src/plugins/mechanisms/mechanisms.dart';
import 'package:whixp/src/plugins/sm/feature.dart';
import 'package:whixp/src/plugins/starttls.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

export 'bind.dart';
export 'mechanisms/feature.dart';
export 'sm/feature.dart';
export 'starttls.dart';

/// Represents stream features stanza.
///
/// This stanza encapsulates features available in the stream negotiation phase.
class StreamFeatures extends Stanza {
  /// Constructs a [StreamFeatures] stanza.
  StreamFeatures();

  static Set<String> supported = <String>{};

  static Set<String> list = <String>{};

  /// StartTLS feature.
  StartTLS? startTLS;

  /// Bind feature.
  Bind? bind;

  /// Available mechanisms.
  SASLMechanisms? mechanisms;

  /// SM
  StreamManagement? sm;

  /// Constructs a [StreamFeatures] stanza from XML.
  factory StreamFeatures.fromXML(xml.XmlElement node) {
    final features = StreamFeatures();

    for (final child in node.children.whereType<xml.XmlElement>()) {
      switch (child.localName) {
        case 'starttls':
          final startTLS = StartTLS.fromXML(child);
          features.startTLS = startTLS;
          list.add(startTLS.name);
        case 'mechanisms':
          final mechanisms = SASLMechanisms.fromXML(child);
          features.mechanisms = mechanisms;
          list.add('mechanisms');
        case 'bind':
          final bind = Bind.fromXML(child);
          features.bind = bind;
          list.add(bind.name);
        case 'sm':
          final sm = StreamManagement();
          features.sm = sm;
          list.add('sm');
      }
    }

    return features;
  }

  @override
  xml.XmlElement toXML() {
    final features = WhixpUtils.xmlElement(name);
    if (startTLS != null) features.children.add(startTLS!.toXML().copy());
    if (mechanisms != null) features.children.add(mechanisms!.toXML().copy());
    if (bind != null) features.children.add(bind!.toXML().copy());

    return features;
  }

  /// Indicates if the stream supports StartTLS.
  bool get doesStartTLS => startTLS != null;

  /// Indicates if TLS is required.
  bool get tlsRequired => startTLS?.required ?? false;

  /// Whether stream management enabled by the server or not.
  bool get doesStreamManagement => sm != null;

  @override
  String get name => 'stream:features';
}
