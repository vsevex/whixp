part of 'mam.dart';

class MAMQuery extends IQStanza {
  const MAMQuery({this.rsm, this.form});

  final RSMSet? rsm;
  final Form? form;

  @override
  xml.XmlElement toXML() {
    final element = WhixpUtils.xmlElement(name, namespace: namespace);
    if (form != null) element.children.add(form!.toXML().copy());
    if (rsm != null) element.children.add(rsm!.toXML().copy());

    return element;
  }

  factory MAMQuery.fromXML(xml.XmlElement node) {
    RSMSet? rsm;
    Form? form;

    for (final child in node.children.whereType<xml.XmlElement>()) {
      if (WhixpUtils.generateNamespacedElement(child) == rsmSetTag) {
        rsm = RSMSet.fromXML(child);
      }
      if (WhixpUtils.generateNamespacedElement(child) == formsTag) {
        form = Form.fromXML(child);
      }
    }

    return MAMQuery(rsm: rsm, form: form);
  }

  @override
  String get name => 'query';

  @override
  String get namespace => WhixpUtils.getNamespace('MAM');

  @override
  String get tag => mamQueryTag;
}

class MAMFin extends IQStanza {
  /// When the results returned by the server are complete (that is: when they
  /// have not been limited by the maximum size of the result page (either as
  /// specified or enforced by the server)), the server MUST include a
  /// 'complete' attribute on the <fin> element, with a value of 'true';
  /// this informs the client that it doesn't need to perform further paging to
  /// retreive the requested data. If it is not the last page of the result set,
  /// the server MUST either omit the 'complete' attribute, or give it a value
  /// of 'false'.
  const MAMFin({this.last, this.complete = false, this.stable});

  final RSMSet? last;
  final bool complete;
  final bool? stable;

  @override
  xml.XmlElement toXML() {
    final attributes = <String, String>{'complete': complete.toString()};
    if (stable != null) attributes['stable'] = stable!.toString();
    final element = WhixpUtils.xmlElement(
      name,
      namespace: namespace,
      attributes: attributes,
    );

    if (last != null) element.children.add(last!.toXML().copy());

    return element;
  }

  factory MAMFin.fromXML(xml.XmlElement node) {
    RSMSet? last;
    bool complete = false;
    bool? stable;

    for (final child in node.children.whereType<xml.XmlElement>()) {
      if (WhixpUtils.generateNamespacedElement(child) == rsmSetTag) {
        last = RSMSet.fromXML(child);
      }
    }

    for (final attribute in node.attributes) {
      if (attribute.localName == 'complete') {
        complete = attribute.value == 'true';
      } else if (attribute.localName == 'stable') {
        stable = attribute.value == 'true';
      }
    }

    return MAMFin(last: last, complete: complete, stable: stable);
  }

  @override
  String get name => 'fin';

  @override
  String get namespace => WhixpUtils.getNamespace('MAM');

  @override
  String get tag => mamFinTag;
}

class MAMMetadata extends IQStanza {
  /// This includes information about the first/last entries in the archive.
  ///
  /// If the archive is not empty, this element MUST include `start` and `end`
  /// elements, which each have an 'id' and XEP-0082 formatted 'timestamp of the
  /// first and last messages in the archive respectively.
  const MAMMetadata({this.start, this.end});

  final Node? start;
  final Node? end;

  @override
  xml.XmlElement toXML() {
    final element = WhixpUtils.xmlElement(name, namespace: namespace);

    if (start != null) {
      element.children.add(start!.toXML());
    } else if (end != null) {
      element.children.add(end!.toXML());
    }

    return element;
  }

  factory MAMMetadata.fromXML(xml.XmlElement node) {
    Node? start;
    Node? end;

    for (final child in node.children.whereType<xml.XmlElement>()) {
      if (child.localName == 'start') {
        start = Node.fromXML(child);
      } else if (child.localName == 'end') {
        end = Node.fromXML(child);
      }
    }

    return MAMMetadata(start: start, end: end);
  }

  @override
  String get name => 'metadata';

  @override
  String get namespace => WhixpUtils.getNamespace('MAM');

  @override
  String get tag => mamMetadataTag;
}

/// The server responds to the archive query by transmitting to the client all
/// the messages that match the criteria the client requested, subject to
/// implementation limits. The results are sent as individual stanzas, with the
/// original message encapsulated in a `forwarded` element.
class MAMResult extends MessageStanza {
  const MAMResult({this.queryID, this.id, this.forwarded});

  /// If the client gave a `queryid` attribute in its initial query, the server
  /// MUST also include that in this result element.
  final String? queryID;
  final String? id;
  final Forwarded? forwarded;

  @override
  xml.XmlElement toXML() {
    final attributes = <String, String>{
      'xmlns': WhixpUtils.getNamespace('MAM'),
    };

    if (queryID?.isNotEmpty ?? false) attributes['queryid'] = queryID!;
    if (id?.isNotEmpty ?? false) attributes['id'] = id!;

    final element = WhixpUtils.xmlElement(
      name,
      namespace: WhixpUtils.getNamespace('MAM'),
      attributes: attributes,
    );

    if (forwarded != null) element.children.add(forwarded!.toXML().copy());

    return element;
  }

  factory MAMResult.fromXML(xml.XmlElement node) {
    String? id;
    String? queryID;
    Forwarded? forwarded;

    for (final attribute in node.attributes) {
      if (attribute.localName == 'id') {
        id = attribute.value;
      } else if (attribute.localName == 'queryid') {
        queryID = attribute.value;
      }
    }

    for (final child in node.children.whereType<xml.XmlElement>()) {
      if (WhixpUtils.generateNamespacedElement(child) == forwardedTag) {
        forwarded = Forwarded.fromXML(child);
      }
    }

    return MAMResult(queryID: queryID, id: id, forwarded: forwarded);
  }

  @override
  String get name => 'result';

  @override
  String get tag => mamResultTag;
}
