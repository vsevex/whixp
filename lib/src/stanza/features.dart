// import 'package:whixp/src/plugins/features.dart';
// import 'package:whixp/src/plugins/plugins.dart';
// import 'package:whixp/src/xml/base.dart';
// import 'package:whixp/src/utils/utils.dart';

// import 'package:xml/xml.dart' as xml;

// /// Represents available features in an XMPP stream.
// ///
// /// Designed to handle incoming features list from the server including both
// /// __required__ and __optional__ features.
// ///
// /// ### Example:
// /// ```xml
// /// <registry type="stream-features">
// ///   <feature>
// ///     <ns>urn:ietf:params:xml:ns:xmpp-bind</ns>
// ///     <name>bind</name>
// ///     <element>bind</element>
// ///     <desc>Support for Resource Binding</desc>
// ///     <doc>RFC 6120: XMPP Core</doc>
// ///   </feature>
// ///   <feature>
// ///     <ns>urn:ietf:params:xml:ns:xmpp-sasl</ns>
// ///     <name>mechanisms</name>
// ///     <element>mechanisms</element>
// ///     <desc>Support for Simple Authentication and Security Layer (SASL)</desc>
// ///     <doc>RFC 6120: XMPP Core</doc>
// ///   </feature>
// /// </registry>
// /// ```
// ///
// /// For more information: [Stream Features](https://xmpp.org/registrar/stream-features.html)
// class StreamFeatures extends StanzaBase {
//   /// Accepts optional XML element property. This comes handy when there is a
//   /// need to parse [XMLBase] from an element or when there is a need to enable
//   /// any plugin externally.
//   ///
//   /// ### Example:
//   /// ```dart
//   /// final features = StreamFeatures();
//   /// final mechanisms = Mechanisms();
//   /// features.registerPlugin(mechanisms);
//   /// features.enable(mechanisms.name);
//   ///
//   /// log(features['mechanisms']);
//   /// ```
//   StreamFeatures({
//     super.pluginTagMapping,
//     super.pluginAttributeMapping,
//     super.element,
//     super.parent,
//   }) : super(
//           name: 'features',
//           namespace: WhixpUtils.getNamespace('JABBER_STREAM'),
//           interfaces: {'features', 'required', 'optional'},
//           subInterfaces: {'features', 'required', 'optional'},
//           getters: {
//             const Symbol('features'): (args, base) {
//               final features = <String, XMLBase>{};
//               for (final plugin in base.plugins.entries) {
//                 features[plugin.key.value1] = plugin.value;
//               }
//               return features;
//             },
//             const Symbol('required'): (args, base) {
//               final features = base['features'] as Map<String, dynamic>;
//               return features.entries
//                   .where(
//                     (entry) => (entry.value as XMLBase)['required'] == true,
//                   )
//                   .map((entry) => entry.value)
//                   .toList();
//             },
//             const Symbol('optional'): (args, base) {
//               final features = base['features'] as Map<String, dynamic>;
//               return features.entries
//                   .where(
//                     (entry) => (entry.value as XMLBase)['required'] == false,
//                   )
//                   .map((entry) => entry.value)
//                   .toList();
//             },
//           },
//         ) {
//     registerPlugin(BindStanza());
//     registerPlugin(Session());
//     registerPlugin(StartTLS());
//     registerPlugin(Mechanisms());
//     registerPlugin(RosterVersioning());
//     registerPlugin(RegisterFeature());
//     registerPlugin(PreApproval());
//     registerPlugin(StreamManagementStanza());
//     registerPlugin(CompressionStanza());
//   }

//   @override
//   StreamFeatures copy({
//     xml.XmlElement? element,
//     XMLBase? parent,
//     bool receive = false,
//   }) =>
//       StreamFeatures(
//         pluginAttributeMapping: pluginAttributeMapping,
//         pluginTagMapping: pluginTagMapping,
//         element: element,
//         parent: parent,
//       );
// }
