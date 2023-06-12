import 'package:echo/src/echo.dart';

import 'event/event.dart';

abstract class Extension<T> extends Event<T> {
  Extension(this.echo);

  Echo echo;

  Future<T> trigger();
}
