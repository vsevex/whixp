import 'package:whixp/src/exception.dart';
import 'package:whixp/src/plugins/features.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/transport.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

final _namespace = WhixpUtils.getNamespace('STARTTLS');

/// Represents a StartTLS stanza.
///
/// This stanza is used to initiate a TLS negotiation.
class StartTLS extends Stanza {
  /// Constructs a [StartTLS] stanza.
  const StartTLS({this.required = false});

  /// Indicates whether TLS is required.
  ///
  /// Default value is `false`.
  final bool required;

  /// Constructs a [StartTLS] stanza from XML.
  factory StartTLS.fromXML(xml.XmlElement node) {
    if (node.getAttribute('xmlns') != _namespace) {
      throw WhixpInternalException.invalidNode(node.localName, 'proceed');
    }

    bool required = false;

    for (final child in node.children.whereType<xml.XmlElement>()) {
      switch (child.localName) {
        case 'required':
          required = true;
      }
    }

    final tls = StartTLS(required: required);

    return tls;
  }

  @override
  xml.XmlElement toXML() {
    final element = WhixpUtils.xmlElement(name, namespace: _namespace);
    if (required) {
      element.children.add(WhixpUtils.xmlElement('required').copy());
    }

    return element;
  }

  /// Handle notification that the server supports TLS.
  static bool handleStartTLS() {
    StreamFeatures.supported.add('starttls');
    Transport.instance().send(const TLSProceed());
    return true;
  }

  @override
  String get name => 'starttls';
}

/// Represents a TLS Proceed stanza.
///
/// This stanza is used to indicate that the TLS negotiation can proceed.
class TLSProceed extends Stanza {
  /// Constructs a [TLSProceed] stanza.
  const TLSProceed();

  /// Constructs a [TLSProceed] stanza from XML.
  factory TLSProceed.fromXML(xml.XmlElement node) {
    if (node.getAttribute('xmlns') != _namespace) {
      throw WhixpInternalException.invalidNode(node.localName, 'proceed');
    }
    return const TLSProceed();
  }

  @override
  xml.XmlElement toXML() => WhixpUtils.xmlElement(name, namespace: _namespace);

  @override
  String get name => 'proceed';
}

/// Represents a TLS Failure stanza.
///
/// This stanza is used to indicate that the TLS negotiation has failed.
class TLSFailure extends Stanza {
  /// Constructs a [TLSFailure] stanza.
  TLSFailure();

  /// Constructs a [TLSFailure] stanza from XML.
  factory TLSFailure.fromXML(xml.XmlElement node) {
    if (node.getAttribute('xmlns') != _namespace) {
      throw WhixpInternalException.invalidNode(node.localName, 'failure');
    }
    return TLSFailure();
  }

  @override
  xml.XmlElement toXML() => WhixpUtils.xmlElement(name, namespace: _namespace);

  @override
  String get name => 'failure';
}
