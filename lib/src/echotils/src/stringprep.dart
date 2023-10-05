import 'package:echox/src/stringprep/stringprep.dart';
import 'package:memoize/memoize.dart';

class StringPreparationProfiles {
  final _nodePrep = StringPreparation().preps['nodeprep'];
  final _resourcePrep = StringPreparation().preps['resourceprep'];

  String? nodePrep(String node) {
    if (_nodePrep == null) return null;
    final check = memo1((String node) => _nodePrep!(node));
    return check(node);
  }

  String? resourcePrep(String resource) {
    if (_resourcePrep == null) return null;
    final check = memo1((String resource) => _resourcePrep!(resource));
    return check(resource);
  }

  void idna(String domain) {
    
  }
}
