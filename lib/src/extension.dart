import 'package:echo/src/echo.dart';

/// Abstract base class for XMPP server plugins to work in the associate of
/// [Echo] package.
///
/// An extension represents a specific functionality or feature that can be
/// added to the XMPP server using [Echo] package. This class provides a common
/// interface and behavior that can be extended by concrete [Extension] classes.
///
/// To create a new extension, you should extend this class and implement the
/// necessary methods and properties.
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
  Extension(this.name);

  /// Initializes [Echo] class.
  Echo? echo;

  /// Initializes [name] property.
  final String name;

  /// Initializes the extension with the provided [echo] instance.
  ///
  /// This method is called during the initialization phase of the extension.
  ///
  /// Note: Do not use this method, unless you need to initialize another
  /// [echo] instance.
  void initialize(Echo echo);

  /// Retrieves the data associated with the extension.
  ///
  /// Returns a [Future] that resolves to the retrieved data of type [T].
  Future<T> get();

  /// Sets the data associated with the extension.
  ///
  /// Returns a [Future] that completes once the data is successfully set.
  Future<void> set();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Extension && name == other.name && echo == other.echo;

  @override
  int get hashCode => name.hashCode ^ echo.hashCode;
}
