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

class LanguageTestStanza extends XMLBase {
  LanguageTestStanza({super.element, super.parent});

  @override
  String get name => 'lerko';

  @override
  String get namespace => 'test';

  @override
  Set<String> get interfaces => {'test'};

  @override
  Set<String> get subInterfaces => interfaces;

  @override
  Set<String> get languageInterfaces => interfaces;
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

class BooleanInterfaceStanza extends XMLBase {
  BooleanInterfaceStanza({super.element, super.parent});

  @override
  String get name => 'foo';

  @override
  String get namespace => 'test';

  @override
  Set<String> get interfaces => {'bar'};

  @override
  Set<String> get boolInterfaces => interfaces;
}

class OverridedStanza extends XMLBase {
  OverridedStanza({super.element, super.parent});

  @override
  String get name => 'foo';

  @override
  String get namespace => 'test';

  @override
  Set<String> get interfaces => {'bar', 'baz'};
}

class ExtensionTestStanza extends XMLBase {
  ExtensionTestStanza({super.element, super.parent});

  @override
  String get name => 'extended';

  @override
  String get namespace => 'test';

  @override
  String get pluginAttribute => name;

  @override
  Set<String> get interfaces => {name};

  @override
  bool get isExtension => true;

  @override
  Map<Symbol, Function> get gettersAndSetters => {
        const Symbol('set_extended'): (value, _) =>
            element!.innerText = value as String,
        const Symbol('get_extended'): (_) => element!.innerText,
        const Symbol('del_extended'): (value, _) =>
            parent!.element!.children.remove(element),
      };

  @override
  XMLBase copy([xml.XmlElement? element, XMLBase? parent]) =>
      ExtensionTestStanza(parent: parent);
}

class OverriderStanza extends OverridedStanza {
  OverriderStanza({super.element, super.parent});

  @override
  String get name => 'overrider';

  @override
  String get namespace => 'test';

  @override
  String get pluginAttribute => name;

  @override
  Set<String> get interfaces => {'bar'};

  @override
  List<String> get overrides => ['set_bar'];

  @override
  bool setup([xml.XmlElement? element]) {
    this.element = xml.XmlElement(xml.XmlName(''));
    return super.setup(element);
  }

  @override
  Map<Symbol, Function> get gettersAndSetters => {
        const Symbol('set_bar'): (value, _) {
          if (!(value as String).startsWith('override-')) {
            parent!.setAttribute('bar', 'override-$value');
          } else {
            parent!.setAttribute('bar', value);
          }
        },
      };
}
