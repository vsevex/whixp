part of 'echo.dart';

/// Abstract base class for XMPP server plugins to work in the associate of
/// [Echo] package.
///
/// An extension represents a specific functionality or feature that can be
/// added to the XMPP server using [Echo] package. This class provides a common
/// interface and behavior that can be extended by concrete [Extension] classes.
///
/// To create a new extension, you should extend this class and implement the
/// necessary methods and properties.
///
/// This abstract class extends [Event] class. This helps to notify extension
/// about new values, helps to add listeners and other functionalities.
abstract class Extension<T> {
  /// Creates an instance of the extension with the specified [name].
  ///
  /// ### Usage
  /// ```dart
  /// class VCardExtension extends Extension<VCard> {
  /// @override
  ///   void initialize(Echo echo) {
  ///     this.echo = echo;
  ///   }
  ///
  /// /// ...other methods should be overridden in order to achieve desired
  /// /// performance of the class.
  /// }
  /// ```
  Extension(this._name);

  /// Initializes [Echo] class.
  late final Echo? echo;

  /// Initializes [name] property.
  final String _name;

  /// Initializes the extension with the provided [echo] instance.
  ///
  /// This method is called during the initialization phase of the extension.
  ///
  /// Note: Do not use this method, unless you need to initialize another
  /// [echo] instance.
  void initialize(Echo echo);

  /// Retrieves the data associated with the extension.
  Future<void> get();

  /// Sets the data associated with the extension.
  ///
  /// Returns a [Future] that completes once the data is successfully set.
  Future<void> set();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Extension && _name == other._name && echo == other.echo;

  @override
  int get hashCode => _name.hashCode ^ echo.hashCode;
}
