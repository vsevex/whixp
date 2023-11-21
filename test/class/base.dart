import 'package:echox/src/stream/base.dart';

import 'package:xml/xml.dart' as xml;

class SimpleStanza extends XMLBase {
  SimpleStanza({super.element, super.parent});

  @override
  String get name => 'lerko';

  @override
  String get namespace => 'test';

  @override
  Set<String> get interfaces => {'hert', 'cart'};
}

class ExtendedNameTestStanza extends XMLBase {
  ExtendedNameTestStanza({super.element, super.parent});

  @override
  String get name => 'foo/bar/baz';

  @override
  String get namespace => 'test';
}

class GetSubTextTestStanza extends XMLBase {
  GetSubTextTestStanza({super.element, super.parent});

  @override
  String get name => 'blya';

  @override
  String get namespace => 'test';

  @override
  Set<String> get interfaces => {'cart'};

  @override
  Map<Symbol, Function> get gettersAndSetters => {
        const Symbol('set_cart'): (value, _) {
          final wrapper = xml.XmlElement(xml.XmlName('wrapper'));
          final cart = xml.XmlElement(xml.XmlName('cart'));
          cart.innerText = 'hehe';
          wrapper.children.add(cart);
          element!.children.add(wrapper);
        },
        const Symbol('get_cart'): (_) {
          return getSubText('/wrapper/cart', def: 'zort');
        },
      };
}

class SubElementTestStanza extends XMLBase {
  SubElementTestStanza({super.element, super.parent});

  @override
  String get name => 'lerko';

  @override
  String get namespace => 'test';

  @override
  Set<String> get interfaces => {'hehe', 'boo'};

  @override
  Map<Symbol, Function> get gettersAndSetters => {
        const Symbol('set_hehe'): (String value, _) =>
            setSubText('/wrapper/hehe', text: value),
        const Symbol('get_hehe'): (_) => getSubText('/wrapper/hehe'),
        const Symbol('set_boo'): (String value, _) =>
            setSubText('/wrapper/boo', text: value),
        const Symbol('get_boo'): (_) => getSubText('/wrapper/boo'),
      };
}

class DeleteSubElementTestStanza extends XMLBase {
  DeleteSubElementTestStanza({super.element, super.parent});

  @override
  String get name => 'lerko';

  @override
  String get namespace => 'test';

  @override
  Set<String> get interfaces => {'hehe', 'boo'};

  @override
  Map<Symbol, Function> get gettersAndSetters => {
        const Symbol('set_hehe'): (String value, _) =>
            setSubText('/wrapper/herto/herto1/hehe', text: value),
        const Symbol('get_hehe'): (_) =>
            getSubText('/wrapper/herto/herto1/hehe'),
        const Symbol('del_hehe'): (_) =>
            deleteSub('/wrapper/herto/herto1/hehe'),
        const Symbol('set_boo'): (String value, _) =>
            setSubText('/wrapper/herto/herto2/boo', text: value),
        const Symbol('get_boo'): (_) => getSubText('/wrapper/herto/herto2/boo'),
        const Symbol('del_boo'): (_) => deleteSub('/wrapper/herto/herto2/boo'),
      };
}

class DefaultLanguageTestStanza extends XMLBase {
  DefaultLanguageTestStanza({super.element, super.parent});

  @override
  String get name => 'foo';

  @override
  String get namespace => 'test';

  @override
  Set<String> get interfaces => {'test'};

  @override
  Set<String> get subInterfaces => interfaces;

  @override
  Set<String> get languageInterfaces => interfaces;
}
