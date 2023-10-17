import 'package:echox/src/stream/base.dart';

class XMLBaseTest extends XMLBase {
  @override
  String get name => 'foo';

  @override
  String get namespace => 'foo';

  @override
  Set<String> get interfaces => {'bar', 'baz', 'qux'};

  @override
  Set<String> get subInterfaces => {'baz'};
}

class XMLBasePluginTest extends XMLBase {
  @override
  String get name => 'foobar';

  @override
  String get namespace => 'foo';

  @override
  Set<String> get interfaces => {'foobar'};

  @override
  String get pluginAttribute => 'foobar';
}
