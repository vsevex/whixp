import 'package:whixp/whixp.dart';

void main() {
  final whixp = Whixp(
    'vsevex@example.com/desktop',
    'passwd',
    host: 'example.com',
    provideHivePath: true,
  );

  final inbandregistration = InBandRegistration();
  whixp.registerPlugin(inbandregistration);

  whixp.addEventHandler('register', (data) {
    final response = whixp.makeIQSet();
    final register = response['register'] as Register;
    register['username'] = 'vsevex';
    register['password'] = 'passwd';
    register['name'] = 'Vsevolod';

    response.sendIQ();
  });

  whixp.connect();
}
