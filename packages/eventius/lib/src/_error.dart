import 'package:error/error.dart';

class TimeoutMishap extends Mishap {
  TimeoutMishap() : super(condition: 'Request timed out');
}
