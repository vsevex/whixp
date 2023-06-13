import 'package:echo/src/echo.dart';

abstract class Extension<T> {
  Extension(this.name);

  Echo? echo;
  final String name;

  void initialize(Echo echo);

  Future<T> get();
  Future<void> set();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Extension && name == other.name && echo == other.echo;

  @override
  int get hashCode => name.hashCode ^ echo.hashCode;
}
