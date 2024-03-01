part of 'tune.dart';

class Tune extends XMLBase {
  Tune({
    super.pluginTagMapping,
    super.pluginAttributeMapping,
    super.element,
    super.parent,
  }) : super(
          name: 'tune',
          namespace: 'http://jabber.org/protocol/tune',
          pluginAttribute: 'tune',
          interfaces: <String>{
            'artist',
            'length',
            'rating',
            'source',
            'title',
            'track',
            'uri',
          },
          subInterfaces: <String>{
            'artist',
            'length',
            'rating',
            'source',
            'title',
            'track',
            'uri',
          },
        );

  void setLength(String length) => setSubText('length', text: length);

  void setRating(String rating) => setSubText('rating', text: rating);

  @override
  Tune copy({xml.XmlElement? element, XMLBase? parent}) => Tune(
        pluginTagMapping: pluginTagMapping,
        pluginAttributeMapping: pluginAttributeMapping,
        element: element,
        parent: parent,
      );
}
