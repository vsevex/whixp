import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/plugins/disco/disco.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/stream/matcher/matcher.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

part 'field.dart';
part 'form.dart';

/// DataForms - XMPP plugin for XEP-0004: Data Forms
///
/// This class is a plugin support for Data Forms (XEP-0004), which defines a
/// protocol for exchanging structured data through forms. This plugin extends
/// the functionality of [PluginBase] and includes methods for handling data
/// forms in the XMPP communication.
///
/// ### Example:
/// ```dart
/// final whixp = Whixp();
/// final form = DataForms();
///
/// whixp.registerPlugin(form); /// registered the [DataForms] plugin in the client
///
/// final createdForm = form.createForm();
/// ```
class DataForms extends PluginBase {
  /// Initializes the [DataForms] instance. It sets the plugin name to `forms`
  /// and provides a description for the plugin. It is dependent to the plugin.
  DataForms()
      : super(
          'forms',
          description: 'XEP-0004: Data Forms',
          dependencies: {'disco'},
        );

  @override
  void pluginInitialize() {
    base.transport.registerHandler(
      CallbackHandler(
        'Data Form',
        (stanza) => base.transport
            .emit<Form>('messageForm', data: stanza['form'] as Form),
        matcher: StanzaPathMatcher('message/form'),
      ),
    );
  }

  /// Creates a new Data Form.
  Form createForm({
    String formType = 'form',
    String title = '',
    String instructions = '',
  }) =>
      Form()
        ..setType(formType)
        ..['title'] = title
        ..['instructions'] = instructions;

  @override
  void sessionBind(String? jid) {
    final disco = base.getPluginInstance<ServiceDiscovery>('disco');
    if (disco != null) {
      disco.addFeature(Form().namespace);
    }
  }

  @override
  void pluginEnd() {
    final disco = base.getPluginInstance<ServiceDiscovery>(
      'disco',
      enableIfRegistered: false,
    );
    if (disco != null) {
      disco.removeFeature(Form().namespace);
    }
    base.transport.removeHandler('Data Form');
  }
}
