import 'package:whixp/src/stream/base.dart';

/// Serves as an abstract class for implementing specific stanzas. It
/// encapsulates a concrete representation of the stanza using [XMLBase] class.
abstract class StanzaConcrete {
  /// Constructs a [StanzaConcrete] instance with the provided concrete
  /// [XMLBase] class.
  ///
  /// This class wraps primary methods, properties and other stuff to make the
  /// implementation of the feature precise and minimal. Hides all
  const StanzaConcrete(this._concrete);

  final XMLBase _concrete;

  XMLBase get concrete => _concrete;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StanzaConcrete &&
          runtimeType == other.runtimeType &&
          _concrete == other._concrete;

  @override
  int get hashCode => _concrete.hashCode;

  /// Returns the serialized format of the concrete [XMLBase] stanza.
  @override
  String toString() => concrete.toString();
}
