import 'package:echox/src/stream/base.dart';

class DefaultLanguageTestStanza extends XMLBase {
  @override
  String get name => 'lerko';

  @override
  String get namespace => 'hert';

  @override
  Set<String> get interfaces => {'hert'};

  @override
  Set<String> get languageInterfaces => interfaces;
}

class TestStanza extends XMLBase {
  @override
  String get name => 'foo';

  @override
  String get namespace => 'foo';

  @override
  Set<String> get interfaces => {};
}

class TestMultiStanza1 extends XMLBase {
  @override
  String get name => 'bar';

  @override
  String get namespace => 'bar';

  @override
  String get pluginAttribute => name;

  @override
  String? get pluginMultiAttribute => 'bars';
}

class TestMultiStanza2 extends XMLBase {
  @override
  String get name => 'baz';

  @override
  String get namespace => 'baz';

  @override
  String get pluginAttribute => name;

  @override
  String? get pluginMultiAttribute => 'bazs';
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
