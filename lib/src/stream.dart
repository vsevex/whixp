import 'dart:async';
import 'dart:convert';

// ignore: implementation_imports
import 'package:xml/src/xml_events/utils/conversion_sink.dart';

import 'package:xml/xml.dart' as xml;
import 'package:xml/xml_events.dart';

/// A result object for [XmlStreamBuffer].
abstract class StreamObject {}

/// A complete XML element returned by the stream buffer.
class StreamElement extends StreamObject {
  StreamElement(this.element);

  /// The actual [xml.XmlNode].
  final xml.XmlElement element;
}

/// The "Stream Header" of a new XML stream.
class StreamHeader extends StreamObject {
  StreamHeader(this.attributes);

  /// Headers of the stream header.
  final Map<String, String> attributes;
}

/// "stream:stream" footer indicator object.
class StreamFooter extends StreamObject {
  StreamFooter();
}

/// A wrapper around a [Converter]'s [Converter.startChunkedConversion] method.
class _ChunkedConversionBuffer<S, T> {
  /// Use the converter [converter].
  _ChunkedConversionBuffer(Converter<S, List<T>> converter) {
    _outputSink = ConversionSink<List<T>>(_results.addAll);
    _inputSink = converter.startChunkedConversion(_outputSink);
  }

  /// The results of the converter.
  final List<T> _results = List<T>.empty(growable: true);

  /// The sink that outputs to [_results].
  late ConversionSink<List<T>> _outputSink;

  /// The sink that we use for input.
  late Sink<S> _inputSink;

  /// Close all opened sinks.
  void close() {
    _inputSink.close();
    _outputSink.close();
  }

  /// Turn the input [input] into a list of [T] according to the initial
  /// converter.
  List<T> convert(S input) {
    _results.clear();
    _inputSink.add(input);
    return _results;
  }
}

/// A buffer to put between a socket's input and a full XML stream.
class StreamParser extends StreamTransformerBase<String, List<StreamObject>> {
  final StreamController<List<StreamObject>> _streamController =
      StreamController<List<StreamObject>>();

  /// Turns a String into a list of [XmlEvent]s in a chunked fashion.
  _ChunkedConversionBuffer<String, XmlEvent> _eventBuffer =
      _ChunkedConversionBuffer<String, XmlEvent>(XmlEventDecoder());

  /// Turns a list of [XmlEvent]s into a list of [xml.XmlNode]s in a chunked fashion.
  _ChunkedConversionBuffer<List<XmlEvent>, xml.XmlNode> _childBuffer =
      _ChunkedConversionBuffer<List<XmlEvent>, xml.XmlNode>(
    const XmlNodeDecoder(),
  );

  /// The selectors.
  _ChunkedConversionBuffer<List<XmlEvent>, XmlEvent> _childSelector =
      _ChunkedConversionBuffer<List<XmlEvent>, XmlEvent>(
    XmlSubtreeSelector((event) => event.qualifiedName != 'stream:stream'),
  );
  _ChunkedConversionBuffer<List<XmlEvent>, XmlEvent> _streamHeaderSelector =
      _ChunkedConversionBuffer<List<XmlEvent>, XmlEvent>(
    XmlSubtreeSelector((event) => event.qualifiedName == 'stream:stream'),
  );

  void reset() {
    try {
      _eventBuffer.close();
    } catch (_) {
      /// Do nothing. A crash here may indicate that we end on invalid XML,
      /// which is fine since we're not going to use the buffer's output anymore.
    }
    try {
      _childBuffer.close();
    } catch (_) {
      /// Do nothing.
    }
    try {
      _childSelector.close();
    } catch (_) {
      /// Do nothing.
    }
    try {
      _streamHeaderSelector.close();
    } catch (_) {
      /// Do nothing.
    }

    /// Recreate the buffers.
    _eventBuffer =
        _ChunkedConversionBuffer<String, XmlEvent>(XmlEventDecoder());
    _childBuffer = _ChunkedConversionBuffer<List<XmlEvent>, xml.XmlNode>(
      const XmlNodeDecoder(),
    );
    _childSelector = _ChunkedConversionBuffer<List<XmlEvent>, XmlEvent>(
      XmlSubtreeSelector((event) => event.qualifiedName != 'stream:stream'),
    );
    _streamHeaderSelector = _ChunkedConversionBuffer<List<XmlEvent>, XmlEvent>(
      XmlSubtreeSelector((event) => event.qualifiedName == 'stream:stream'),
    );
  }

  @override
  Stream<List<StreamObject>> bind(Stream<String> stream) {
    /// We do not want to use xml's `toXmlEvents` and `toSubtreeEvents` methods
    /// as they create streams we cannot close. We need to be able to destroy
    /// and recreate an XML parser whenever we start a new connection.
    stream.listen((input) {
      final events = _eventBuffer.convert(input);
      final streamHeaderEvents = _streamHeaderSelector.convert(events);
      final objects = List<StreamObject>.empty(growable: true);

      // Process the stream header separately.
      for (final event in streamHeaderEvents) {
        if (event is! XmlStartElementEvent) {
          continue;
        }

        if (event.name != 'stream:stream') {
          continue;
        } else {
          if (event.attributes.isEmpty) objects.add(StreamFooter());
        }

        objects.add(
          StreamHeader(
            Map<String, String>.fromEntries(
              event.attributes.map(
                (attributes) => MapEntry(attributes.name, attributes.value),
              ),
            ),
          ),
        );
      }

      // Process the children of the <stream:stream> element.
      final childEvents = _childSelector.convert(events);
      final children = _childBuffer.convert(childEvents);
      for (final node in children) {
        if (node.nodeType == XmlNodeType.ELEMENT) {
          objects.add(StreamElement(node as xml.XmlElement));
        }
      }

      _streamController.add(objects);
    });

    return _streamController.stream;
  }
}
