import 'dart:async';

import 'package:synchronized/synchronized.dart';

import 'package:whixp/src/whixp.dart';

/// Manages the registration and activation of XMPP plugins.
///
/// Provides functionality for registering, enabling, and managing XMPP plugins.
///
/// ### Example:
/// ```dart
/// final manager = PluginManager();
/// manager.register('starttls', FeatureStartTLS());
/// ```
class PluginManager {
  /// A [Set] containing the names of currently enabled plugins.
  final enabledPlugins = <String>{};

  /// A [Map] containing the names and instances of currently active plugins.
  final activePlugins = <String, PluginBase>{};

  /// A reentrant lock used to synchronize access to the plugin manager's data
  /// structures.
  final _lock = Lock(reentrant: true);

  /// A [Map] containing registered plugins with their names as keys.
  final _pluginRegistery = <String, PluginBase>{};

  /// A [Map] containing plugin dependencies, where each entry maps a plugin
  /// name to its dependents.
  final _pluginDependents = <String, Set<String>>{};

  /// A [Completer] used to signal the completion of locked operations.
  late Completer<dynamic> _lockCompleter;

  /// Registers a plugin with the specified [name].
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

  /// Enables a plugin and its dependencies.
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

  /// Checks if a plugin with the given [name] is registered.
  bool registered(String name) => _pluginRegistery.containsKey(name);
}

/// An abstract class representing the base structure for XMPP plugins.
///
/// Implementations of this class are intended to provide functionality related
/// to specific XMPP features or extensions.
///
/// ### Example:
/// ```dart
/// class FeatureStartTLS extends BasePlugin {
///    const FeatureStartTLS(this._features, {required super.base})
///       : super(
///           'starttls',
///           description: 'Stream Feature: STARTTLS',
///         );
/// }
/// ```
abstract class PluginBase {
  /// Creates an instance [PluginBase] with the specified parameters.
  const PluginBase(
    /// Short name
    this.name, {
    /// [WhixpBase] instance
    required this.base,

    /// Long name
    this.description = '',

    /// Plugin related dependencies
    this.dependencies = const <String>{},
  });

  /// A short name for the plugin based on the implemented specification.
  ///
  /// For example, a plugin for StartTLS would use "starttls".
  final String name;

  /// A longer name for the plugin, describing its purpose. For example a
  /// plugin for StartTLS would use "Stream Feature: STARTTLS" as its
  /// description value.
  final String description;

  /// Some plugins may depend on others in order to function properly. Any
  /// plugins names included in [dependencies] will be initialized as
  /// needed if this plugin is enabled.
  final Set<String> dependencies;

  /// [WhixpBase] instance to use accross the plugin implementation.
  final WhixpBase base;

  /// Initializes the plugin. Concrete implementations should override this
  /// method to perform necessary setup or initialization.
  void initialize();
}
