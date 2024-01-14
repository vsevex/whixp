import 'package:dartz/dartz.dart';
import 'package:meta/meta.dart';

import 'package:whixp/src/handler/handler.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/plugins/base.dart';
import 'package:whixp/src/plugins/disco/disco.dart';
import 'package:whixp/src/stanza/implementation.dart';
import 'package:whixp/src/stream/base.dart';
import 'package:whixp/src/stream/matcher/matcher.dart';
import 'package:whixp/src/utils/utils.dart';

import 'package:xml/xml.dart' as xml;

part 'field.dart';
part 'form.dart';

/// DataForm - XMPP plugin for XEP-0004: Data Forms
///
/// This class is a plugin support for Data Forms (XEP-0004), which defines a
/// protocol for exchanging structured data through forms. This plugin extends
/// the functionality of [PluginBase] and includes methods for handling data
/// forms in the XMPP communication.
///
/// ### Example:
/// ```dart
/// final whixp = Whixp();
/// final form = DataForm();
///
/// whixp.registerPlugin(form); /// registered the [DataForm] plugin in the client
///
/// final createdForm = form.createForm();
/// ```
class DataForm extends PluginBase {
  /// Initializes the [DataForm] instance. It sets the plugin name to `forms`
  /// and provides a description for the plugin. It is dependent to the plugin.
  DataForm()
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
        (stanza) => base.transport.emit<Form>(
          'messageForm',
          data: Form(stanza['form'] as FormAbstract),
        ),
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
      Form(
        FormAbstract()
          ..setType(formType)
          ..['title'] = title
          ..['instructions'] = instructions,
      );

  @override
  void sessionBind(String? jid) {
    final disco = base.getPluginInstance<ServiceDiscovery>('disco');
    if (disco != null) {
      disco.addFeature(FormAbstract().namespace);
    }
  }

  @override
  void pluginEnd() {
    final disco = base.getPluginInstance<ServiceDiscovery>(
      'disco',
      enableIfRegistered: false,
    );
    if (disco != null) {
      disco.removeFeature(FormAbstract().namespace);
    }
    base.transport.removeHandler('Data Form');
  }
}