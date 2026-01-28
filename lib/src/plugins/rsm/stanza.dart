part of 'rsm.dart';

/// 1. Limit the number of items returned.
/// 2. Page forwards or backwards through a result set by retrieving the items
/// in smaller subsets.
/// 3. Discover the size of a result set without retrieving the items themselves.
/// 4. Retrieve a page (subset) of items starting at any point in a result set.
///
/// ### Example:
/// ```dart
/// const rsm = RSMSet(max: 10);
///
/// /// Generates the following stanza:
/// '<set xmlns="http://jabber.org/protocol/rsm"><max>10</max></set>'
/// ```
class RSMSet extends IQStanza {
  const RSMSet({
    this.max = 0,
    this.after,
    this.before,
    this.count,
    this.firstIndex,
    this.firstItem,
    this.lastItem,
    this.index,
  });

  /// In order to limit the number of items of a result set to be returned,
  /// the requesting entity specifies the maximum size of the desired subset
  /// (via the XML character data of the max element).
  final int max;

  /// The requesting entity can then ask for the next page in the result set
  /// by including in its request the UID of the last item from the previous
  /// page (encapsulated in an after element), along with the maximum number
  /// of items to return. Note: If no after element is specified, then the
  /// UID defaults to "before the first item in the result set" (i.e.,
  /// effectively an index of negative one).
  final String? after;

  /// The requesting entity MAY ask for the previous page in a result set by
  /// including in its request the UID of the first item from the page that has
  /// already been received (encapsulated in a before element), along with
  /// the maximum number of items to return.
  ///
  /// If set to an empty string, then before element will be added.
  final String? before;

  /// In order to get the item count of a result set without retrieving the
  /// items themselves, the requesting entity simply specifies zero for the
  /// maximum size of the result set page.
  ///
  /// Remember, you can not set count in set stanza, this property is required
  /// when result stanza is accepted.
  final int? count;

  /// The `firstItem` should include an index attribute. This integer specifies
  /// the position within the full set (which MAY be approximate) of the first
  /// item in the page. If that item is the first in the full set, then the
  /// index SHOULD be '0' (zero). If the last item in the page is the last item
  /// in the full set, then the value of the first element's index attribute
  /// SHOULD be the specified count minus the number of items in the last page.
  final int? firstIndex;

  /// The responding entity MUST include `first` element that specify the unique
  /// ID (UID) for the first and last items in the page.
  final String? firstItem;

  /// The responding entity MUST include `last` element that specify the unique
  /// ID (UID) for the first and last items in the page. If there is only one
  /// item in the page, then the first and last UIDs MUST be the same. If there
  /// are no items in the page, then the `first` and `last` elements MUST NOT be
  /// included.
  final String? lastItem;

  /// Only if the UID before the start (or after the end) of a desired result
  /// set page is not known, then the requesting entity MAY request the page
  /// that starts at a particular index within the result set. It does that by
  /// including in its request the index of the first item to be returned
  /// (encapsulated in an index element), as well as the maximum number of
  /// items to return.
  final int? index;

  @override
  xml.XmlElement toXML() {
    final builder = WhixpUtils.makeGenerator();
    final attributes = <String, String>{'xmlns': namespace};

    builder.element(
      name,
      attributes: attributes,
      nest: () {
        builder.element('max', nest: () => builder.text(max));

        if (after?.isNotEmpty ?? false) {
          builder.element('after', nest: () => builder.text(after!));
        }

        if (before != null) {
          builder.element(
            'before',
            nest: () {
              if (before!.isNotEmpty) builder.text(before!);
            },
          );
        }

        if ((firstItem?.isNotEmpty ?? false) && firstIndex != null) {
          builder.element(
            'first',
            attributes: <String, String>{'index': firstIndex!.toString()},
            nest: () => builder.text(firstItem!),
          );
        }

        if (lastItem?.isNotEmpty ?? false) {
          builder.element('last', nest: () => builder.text(lastItem!));
        }

        if (index != null) {
          builder.element('index', nest: () => builder.text(index!));
        }
      },
    );

    return builder.buildDocument().rootElement;
  }

  factory RSMSet.fromXML(xml.XmlElement node) {
    int max = 0;
    String? before;
    String? after;
    int? count;

    int? firstIndex;
    String? firstItem;
    String? lastItem;
    int? index;

    for (final child in node.children.whereType<xml.XmlElement>()) {
      if (child.localName == 'count') {
        count = int.parse(child.innerText);
      } else if (child.localName == 'max') {
        max = int.parse(child.innerText);
      } else if (child.localName == 'after') {
        after = child.innerText;
      } else if (child.localName == 'before') {
        before = child.innerText;
      } else if (child.localName == 'first') {
        for (final attribute in child.attributes) {
          if (attribute.localName == 'index') {
            firstIndex = int.parse(attribute.value);
          }
        }
        firstItem = child.innerText;
      } else if (child.localName == 'last') {
        lastItem = child.innerText;
      } else if (child.localName == 'index') {
        index = int.parse(child.innerText);
      }
    }

    return RSMSet(
      max: max,
      count: count,
      before: before,
      after: after,
      firstIndex: firstIndex,
      firstItem: firstItem,
      lastItem: lastItem,
      index: index,
    );
  }

  bool get isBefore => before != null && before!.isEmpty;

  @override
  String get name => 'set';

  @override
  String get namespace => WhixpUtils.getNamespace('RSM');

  @override
  String get tag => rsmSetTag;
}
