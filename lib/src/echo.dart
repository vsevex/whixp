import 'package:echo/src/constants.dart';

class Echo {
  /// `version` constant
  static const version = '0.0.1';

  /// Utility method that determines whether `tag` is valid or not.
  ///
  /// Accepts only a parameter which refers to tag, and passes this tag for
  /// further investigation.
  bool isTagValid(String tag) {
    /// Final variable that equals to `tags` list from constants.
    final tags = xhtml['tags'] as List<String>;

    /// For method for checking all tags according to passed `tag` variable.
    for (int i = 0; i < tags.length; i++) {
      if (tag == tags[i]) {
        return true;
      }
    }
    return false;
  }

  bool isAttributeValid(String tag, String attribute) {
    final tags = xhtml['tags'] as List<String>;
    final attributes = xhtml['attributes'] as Map<String, List<String>>;

    for (int i = 0; i < attributes[tag]!.length; i++) {
      if (attribute == attributes[tag]![i]) {
        return true;
      }
    }
  }
}
