part of 'base.dart';

class _ElementPluginRegistrator {
  factory _ElementPluginRegistrator() => _instance;

  _ElementPluginRegistrator._();

  static final _ElementPluginRegistrator _instance =
      _ElementPluginRegistrator._();

  final _plugins = <String, BaseElement>{};

  BaseElement get(String name) {
    assert(_plugins.containsKey(name), '$name plugin is not registered');
    return _plugins[name]!;
  }

  void register(String name, BaseElement element) {
    if (_plugins.containsKey(name)) return;

    _plugins[name] = element;
  }

  void unregister(String name) {
    if (!_plugins.containsKey(name)) return;

    _plugins.remove(name);
  }

  void clear() => _plugins.clear();
}
