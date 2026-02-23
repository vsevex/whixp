import 'package:test/test.dart';

import 'package:whixp/src/enums.dart';
import 'package:whixp/src/exception.dart';
import 'package:whixp/src/jid/jid.dart';
import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/native/transport_ffi.dart'
    show isNativeTransportAvailable;
import 'package:whixp/src/reconnection.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/transport.dart';

void main() {
  setUp(() {
    // Initialize Log singleton before each test
    Log(enableDebug: false, enableInfo: false);
  });

  group(
    'Transport',
    () {
      test('can create multiple independent instances', () {
        final transport1 = Transport('example.com');
        final transport2 = Transport('example.org', port: 5223);

        expect(transport1, isNot(same(transport2)));
        expect(transport1.boundJID, isNull);
        expect(transport2.boundJID, isNull);
      });

      test('initializes with correct default values', () {
        final transport = Transport('example.com');

        expect(transport.pingKeepAlive, isTrue);
        expect(transport.pingKeepAliveInterval, 180);
        expect(transport.boundJID, isNull);
      });

      test('initializes with custom configuration', () {
        final boundJID = JabberID('user@example.com');
        final transport = Transport(
          'example.com',
          port: 5223,
          boundJID: boundJID,
          pingKeepAlive: false,
          pingKeepAliveInterval: 300,
          useTLS: true,
          disableStartTLS: true,
        );

        expect(transport.pingKeepAlive, isFalse);
        expect(transport.pingKeepAliveInterval, 300);
        expect(transport.boundJID, equals(boundJID));
      });

      test('exposes connection property', () {
        final transport = Transport('example.com');
        expect(transport.connection, isNotNull);
        expect(transport.connection.configuration.host, equals('example.com'));
      });

      test('can set boundJID after initialization', () {
        final transport = Transport('example.com');
        final jid = JabberID('user@example.com/resource');

        transport.boundJID = jid;
        expect(transport.boundJID, equals(jid));
      });

      group('State Management', () {
        test('emits state changes', () {
          final transport = Transport('example.com');
          final states = <TransportState>[];

          // Use a custom event name to avoid triggering internal cleanup handlers
          // that require initialized streams (_waitingQueueController)
          transport.addEventHandler<TransportState>('testState', (state) {
            if (state != null) {
              states.add(state);
            }
          });

          // Manually emit a state change to test event handling
          transport.emit<TransportState>('testState',
              data: TransportState.connecting);

          // Should have received the state change
          expect(states, isNotEmpty);
          expect(states.first, equals(TransportState.connecting));
        });

        test('handles multiple state listeners', () {
          final transport = Transport('example.com');
          final states1 = <TransportState>[];
          final states2 = <TransportState>[];

          // Use a custom event name to avoid triggering internal cleanup
          transport.addEventHandler<TransportState>('testState', (state) {
            if (state != null) {
              states1.add(state);
            }
          });
          transport.addEventHandler<TransportState>('testState', (state) {
            if (state != null) {
              states2.add(state);
            }
          });

          // Manually emit a state change
          transport.emit<TransportState>('testState',
              data: TransportState.connecting);

          expect(states1, isNotEmpty);
          expect(states2, isNotEmpty);
          expect(states1.length, equals(states2.length));
          expect(states1.first, equals(TransportState.connecting));
          expect(states2.first, equals(TransportState.connecting));
        });

        test('internal state handler is registered and works', () {
          final transport = Transport('example.com');
          bool handlerCalled = false;

          // Add a handler for the 'state' event
          // Use connecting state to avoid triggering cleanup logic that requires
          // initialized streams (_waitingQueueController)
          transport.addEventHandler<TransportState>('state', (state) {
            if (state == TransportState.connecting) {
              handlerCalled = true;
            }
          });

          // Emit connecting state (doesn't trigger cleanup)
          transport.emit<TransportState>('state',
              data: TransportState.connecting);

          expect(handlerCalled, isTrue);
        });
      });

      group('Error Handling', () {
        test('handles connection errors gracefully', () async {
          final transport = Transport('example.com');

          transport.addEventHandler<Object>('connectionFailure', (error) {
            // Error handler registered - error may be emitted depending on reconnection policy
          });

          // Simulate error handling - this will trigger async error handling
          final testError = Exception('Test error');
          transport.connection.handleError(testError);

          // Wait for async operations
          await Future.delayed(const Duration(milliseconds: 100));

          // Error should be handled without throwing (may or may not emit depending on reconnection policy)
          // The important thing is it doesn't throw
          expect(transport.connection, isNotNull);
        });

        test('error handler includes context information', () {
          final exception = AuthenticationException.failed(
            reason: 'Invalid credentials',
            mechanism: 'PLAIN',
          );

          expect(exception.code, equals('AUTH_FAILED'));
          expect(exception.recoverySuggestion, isNotNull);
          expect(exception.message, contains('PLAIN'));
          expect(exception.message, contains('Invalid credentials'));
        });
      });

      group('Reconnection Policy', () {
        test('can set reconnection policy', () {
          final policy = RandomBackoffReconnectionPolicy(1, 5);
          final transport = Transport(
            'example.com',
            reconnectionPolicy: policy,
          );

          // Policy should be set (we can't directly access it, but we can test behavior)
          expect(policy.performReconnect, isNotNull);
          expect(transport.connection, isNotNull);
        });

        test('handles reconnection policy state', () async {
          final policy = RandomBackoffReconnectionPolicy(1, 2);
          final transport = Transport(
            'example.com',
            reconnectionPolicy: policy,
          );

          await policy.setShouldReconnect(true);
          expect(await policy.getShouldReconnect(), isTrue);

          await policy.setShouldReconnect(false);
          expect(await policy.getShouldReconnect(), isFalse);
          expect(transport.connection, isNotNull);
        });

        test('hangup resets reconnection policy and cancels backoff timer',
            () async {
          final policy = RandomBackoffReconnectionPolicy(1, 5);
          final transport = Transport(
            'example.com',
            reconnectionPolicy: policy,
          );
          await policy.setShouldReconnect(true);
          final triggered = await policy.canTriggerFailure();
          expect(triggered, isTrue);
          await policy.onFailure();
          expect(policy.isTimerRunning(), isTrue);

          await transport.connection.hangup(
            consume: false,
            sendFooter: false,
          );

          expect(await policy.getShouldReconnect(), isFalse);
          expect(await policy.getIsReconnecting(), isFalse);
          expect(policy.isTimerRunning(), isFalse);
        });

        test('canTriggerFailure only allows one attempt at a time', () async {
          final policy = RandomBackoffReconnectionPolicy(1, 3);
          Transport('example.com', reconnectionPolicy: policy);
          await policy.setShouldReconnect(true);

          final first = await policy.canTriggerFailure();
          expect(first, isTrue);
          final second = await policy.canTriggerFailure();
          expect(second, isFalse);

          await policy.reset();
          final afterReset = await policy.canTriggerFailure();
          expect(afterReset, isTrue);
        });
      });

      group('Event Handling', () {
        test('can add and remove event handlers', () {
          final transport = Transport('example.com');
          bool handlerCalled = false;

          void handler(dynamic _) {
            handlerCalled = true;
          }

          transport.addEventHandler('testEvent', handler);

          transport.emit('testEvent', data: 'test');
          expect(handlerCalled, isTrue);

          handlerCalled = false;
          transport.removeEventHandler('testEvent', handler: handler);
          transport.emit('testEvent', data: 'test');
          expect(handlerCalled, isFalse);
        });

        test('handles typed event handlers', () {
          final transport = Transport('example.com');
          String? receivedData;

          transport.addEventHandler<String>('testEvent', (data) {
            receivedData = data;
          });

          transport.emit('testEvent', data: 'test data');
          expect(receivedData, equals('test data'));
        });
      });

      group('Exception Classes', () {
        test('WhixpInternalException includes error codes', () {
          final exception = WhixpInternalException.invalidXML();

          expect(exception.code, equals('INVALID_XML'));
          expect(exception.recoverySuggestion, isNotNull);
          expect(exception.toString(), contains('INVALID_XML'));
        });

        test('AuthenticationException provides recovery suggestions', () {
          final exception = AuthenticationException.requiresTLS();

          expect(exception.code, equals('TLS_REQUIRED'));
          expect(exception.recoverySuggestion, isNotNull);
          expect(exception.recoverySuggestion, contains('disableStartTLS'));
        });

        test('SASLException includes mechanism context', () {
          final exception = SASLException.missingCredentials(
            'password',
          );

          expect(exception.code, equals('MISSING_CREDENTIAL'));
          expect(exception.recoverySuggestion, isNotNull);
          expect(exception.message, contains('password'));
        });

        test('StanzaException includes timeout duration', () {
          final iq = IQ()..id = 'test-123';
          final exception = StanzaException.timeout(iq, timeoutSeconds: 10);

          expect(exception.message, contains('10'));
          expect(exception.condition, equals('remote-server-timeout'));
        });
      });

      group('Multiple Instances Isolation', () {
        test('instances have independent state', () {
          final transport1 = Transport('example.com');
          final transport2 = Transport('example.org');

          final jid1 = JabberID('user1@example.com');
          final jid2 = JabberID('user2@example.org');

          transport1.boundJID = jid1;
          transport2.boundJID = jid2;

          expect(transport1.boundJID, equals(jid1));
          expect(transport2.boundJID, equals(jid2));
          expect(transport1.boundJID, isNot(equals(transport2.boundJID)));
        });

        test('instances have independent event handlers', () {
          final transport1 = Transport('example.com');
          final transport2 = Transport('example.org');

          bool handler1Called = false;
          bool handler2Called = false;

          transport1.addEventHandler('test', (_) {
            handler1Called = true;
          });
          transport2.addEventHandler('test', (_) {
            handler2Called = true;
          });

          transport1.emit('test');
          expect(handler1Called, isTrue);
          expect(handler2Called, isFalse);

          handler1Called = false;
          transport2.emit('test');
          expect(handler1Called, isFalse);
          expect(handler2Called, isTrue);
        });

        test('instances have independent reconnection policies', () {
          final policy1 = RandomBackoffReconnectionPolicy(1, 3);
          final policy2 = RandomBackoffReconnectionPolicy(2, 5);

          final transport1 = Transport(
            'example.com',
            reconnectionPolicy: policy1,
          );
          final transport2 = Transport(
            'example.org',
            reconnectionPolicy: policy2,
          );

          // Policies should be independent instances
          expect(policy1, isNot(same(policy2)));
          expect(policy1.performReconnect, isNotNull);
          expect(policy2.performReconnect, isNotNull);
          expect(transport1.connection, isNot(same(transport2.connection)));
          expect(
              transport1.connection.configuration.host, equals('example.com'));
          expect(
              transport2.connection.configuration.host, equals('example.org'));
        });
      });

      group('Connection Configuration', () {
        test('preserves connection settings', () {
          final transport = Transport(
            'example.com',
            port: 5223,
            useTLS: true,
            disableStartTLS: true,
            useIPv6: true,
            connectionTimeout: 5000,
          );

          expect(
              transport.connection.configuration.host, equals('example.com'));
          expect(transport.connection.configuration.port, equals(5223));
          expect(transport.connection.configuration.useTLS, isTrue);
          expect(transport.connection.configuration.disableStartTLS, isTrue);
          expect(
            transport.connection.configuration.useIPv6WhenResolvingDNS,
            isTrue,
          );
          expect(
            transport.connection.configuration.connectionTimeout,
            equals(5000),
          );
        });
      });
    },
    skip: isNativeTransportAvailable
        ? null
        : 'Native transport not loaded (set WHIXP_TEST_NATIVE=1 to run with native)',
  );
}
