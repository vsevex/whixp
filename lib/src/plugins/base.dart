import 'dart:async';

import 'package:echox/src/client.dart';

import 'package:synchronized/synchronized.dart';

class PluginManager {
  Set<String> enabledPlugins = <String>{};
  final activePlugins = <String, PluginBase>{};
  final _lock = Lock(reentrant: true);
  late Completer<dynamic> _lockCompleter;
  final _pluginRegistery = <String, PluginBase>{};
  final _pluginDependents = <String, Set<String>>{};

  void register(String name, PluginBase plugin) {
    _lockCompleter = Completer<dynamic>();

    _lockCompleter.complete(
      _lock.synchronized(() async {
        _pluginRegistery[name] = plugin;
        if (_pluginDependents.containsKey(name) &&
            _pluginDependents[name] != null &&
            _pluginDependents[name]!.isNotEmpty) {
          for (final dependent in plugin.dependencies) {
            _pluginDependents[dependent]!.add(name);
          }
        } else {
          _pluginDependents[name] = <String>{};
        }
      }),
    );
  }

  void enable(String name, {Set<String>? enabled}) {
    final enabledTemp = enabled ?? {};
    _lockCompleter = Completer<dynamic>();

    _lockCompleter.complete(
      _lock.synchronized(() {
        enabledTemp.add(name);
        enabledPlugins.add(name);
        if (_pluginRegistery.containsKey(name) &&
            _pluginRegistery[name] != null) {
          final plugin = _pluginRegistery[name]!;
          activePlugins[name] = plugin;
          if (plugin.dependencies.isNotEmpty) {
            for (final dependency in plugin.dependencies) {
              enable(dependency, enabled: enabledTemp);
            }
          }
          plugin.initialize();
        }
        return;
      }),
    );
  }

  bool registered(String name) => _pluginRegistery.containsKey(name);
}

abstract class PluginBase {
  const PluginBase(
    this.name, {
    required this.base,
    this.description = '',
    this.dependencies = const <String>{},
    this.config = const <String, dynamic>{},
  });

  final String name;
  final String description;
  final Set<String> dependencies;
  final Map<String, dynamic> config;
  final Whixp base;

  void initialize();
}
