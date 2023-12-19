import 'package:echox/src/echotils/echotils.dart';
import 'package:echox/src/stream/base.dart';

class StreamFeatures extends StanzaBase {
  StreamFeatures()
      : super(
          name: 'features',
          namespace: Echotils.getNamespace('JABBER_STREAM'),
          interfaces: {'features', 'required', 'optional'},
          subInterfaces: {'features', 'required', 'optional'},
          pluginAttributeMapping: {},
          pluginTagMapping: {},
          setters: {
            const Symbol('features'): (value, args, base) {},
          },
          getters: {
            const Symbol('features'): (args, base) {
              final features = <String, XMLBase>{};
              for (final plugin in base.plugins.entries) {
                features[plugin.key.value1] = plugin.value;
              }
              return features;
            },
            const Symbol('required'): (args, base) {
              final features = base['features'] as Map<String, dynamic>;
              return features.entries
                  .where((entry) => entry.value['required'] == true)
                  .map((entry) => entry.value)
                  .toList();
            },
            const Symbol('optional'): (args, base) {
              final features = base['features'] as Map<String, dynamic>;
              return features.entries
                  .where((entry) => entry.value['required'] == false)
                  .map((entry) => entry.value)
                  .toList();
            },
          },
        );
}
