import 'package:whixp/src/_static.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

part 'stanza.dart';

/// An entity often needs to retrieve a page of items adjacent to a page it has
/// already received. For examples, when retrieving a complete result set in
/// order page by page, or when a user 'scrolls' forwards one page.
///
/// The set of items that match a query MAY change over time, even during the
/// time that a requesting entity pages through the result set (e.g., a set of
/// chatrooms, since rooms can be created and destroyed at any time). The paging
/// protocol outlined in this section is designed so that entities MAY provide
/// the following features:
///
/// * Each page of the result set is up-to-date at the time it is sent (not just
/// at the time the first page was sent).
/// * No items will be omitted from pages not yet sent (even if, after earlier
/// pages were sent, some of the items they contained were removed from the set).
/// * When paging through the list in order, duplicate items are never received.
/// * The responding entity maintains no state (or a single minimal state for
/// all requesting entities containing the positions of all recently deleted
/// items).
/// * Rapid calculation of which items should appear on a requested page by
/// responding entity (even for large result sets).
///
/// Note: If a responding entity implements dynamic result sets then receiving
/// entities paging through the complete result set should be aware that it may
/// not correspond to the result set as it existed at any one point in time.
///
/// More information: <https://xmpp.org/extensions/xep-0059.html>
class RSM {
  const RSM();

  /// [max] must be declared in this case due the stanza will be created with
  /// the proper value and can be later set to `IQ` stanza.
  static RSMSet limitNumberOfItems(int max) => RSMSet(max: max);

  /// Creates an empty before element, [max] must be declared.
  static RSMSet pageBackwards(int max) => RSMSet(max: max, before: '');

  /// The requesting entity MAY ask for the last page in a result set by
  /// including in its request an empty before element, and the maximum
  /// number of items to return.
  static RSMSet requestLastPage(int max) => RSMSet(max: max, before: '');

  static RSMSet retrievePageOutOfOrder(int index, {int max = 0}) =>
      RSMSet(max: max, index: index);

  /// Builds an [RSMSet] stanza to get the count of items from the server.
  static RSMSet getItemCount() => const RSMSet();
}
