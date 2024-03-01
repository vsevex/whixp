import 'package:whixp/whixp.dart';

void main() {
  final whixp = Whixp(
    'vsevex@example.com/desktop',
    'passwd',
    host: 'example.com',
    logger: Log(enableError: true, enableWarning: true),
    provideHivePath: true,
  );

  final management = StreamManagement(smID: 'someID');
  whixp.connect();
  whixp.registerPlugin(management);
}
