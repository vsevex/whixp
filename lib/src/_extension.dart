// part of 'echox.dart';

// /// Abstract base class for XMPP server plugins to work in the associate of
// /// [EchoX] package.
// ///
// /// An extension represents a specific functionality or feature that can be
// /// added to the XMPP server using [EchoX] package. This class provides a common
// /// interface and behavior that can be extended by concrete [Extension] classes.
// ///
// /// To create a new extension, you should extend this class and implement the
// /// necessary methods and properties.
// abstract class Extension {
//   /// Creates an instance of the extension with the specified [name].
//   ///
//   /// ### Usage
//   /// ```dart
//   /// class VCardExtension extends Extension<VCard> {
//   /// @override
//   ///   void initialize(EchoX echox) {
//   ///     this.echox = echox;
//   ///   }
//   ///
//   /// /// ...other methods should be overridden in order to achieve desired
//   /// /// performance of the class.
//   /// }
//   /// ```
//   Extension(this._name);

//   /// Initializes [EchoX] class.
//   late final EchoX? echox;

//   /// Initializes [name] property.
//   final String _name;

//   /// Initializes the extension with the provided [echox] instance.
//   ///
//   /// This method is called during the initialization phase of the extension.
//   ///
//   /// Note: Do not use this method, unless you need to initialize another
//   /// [echox] instance.
//   void initialize(EchoX echox);

//   /// If there will be any logic that needs to be done on the specific status
//   /// change, then this method will come to help.
//   void changeStatus(EchoStatus status, String? condition);

//   @override
//   bool operator ==(Object other) =>
//       identical(this, other) ||
//       other is Extension && _name == other._name && echox == other.echox;

//   @override
//   int get hashCode => _name.hashCode ^ echox.hashCode;
// }
