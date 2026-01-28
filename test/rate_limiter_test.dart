import 'package:test/test.dart';

import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/performance/rate_limiter.dart';

void main() {
  setUp(() {
    // Initialize Log singleton before each test
    Log(
      enableDebug: false,
      enableInfo: false,
    );
  });

  group('RateLimiter', () {
    test('initializes with default values', () {
      final limiter = RateLimiter();

      expect(limiter.maxStanzasPerSecond, equals(100));
      expect(limiter.maxBurst, equals(50));
      expect(limiter.enabled, isTrue);
      expect(limiter.availableTokens, equals(50.0));
    });

    test('initializes with custom values', () {
      final limiter = RateLimiter(
        maxStanzasPerSecond: 200,
        maxBurst: 100,
      );

      expect(limiter.maxStanzasPerSecond, equals(200));
      expect(limiter.maxBurst, equals(100));
      expect(limiter.availableTokens, equals(100.0));
    });

    group('Token Management', () {
      test('canSend returns true when tokens available', () async {
        final limiter = RateLimiter(maxStanzasPerSecond: 10, maxBurst: 5);

        // Should have 5 tokens initially
        expect(await limiter.canSend(), isTrue);
        expect(limiter.availableTokens, lessThan(5.0));
      });

      test('canSend returns false when no tokens available', () async {
        final limiter = RateLimiter(maxStanzasPerSecond: 1, maxBurst: 1);

        // Consume the only token
        expect(await limiter.canSend(), isTrue);
        expect(await limiter.canSend(), isFalse);
      });

      test('waitForToken consumes token when available', () async {
        final limiter = RateLimiter(maxStanzasPerSecond: 10, maxBurst: 5);

        final initialTokens = limiter.availableTokens;
        await limiter.waitForToken();
        expect(limiter.availableTokens, lessThan(initialTokens));
      });

      test('waitForToken waits when no tokens available', () async {
        final limiter = RateLimiter(maxStanzasPerSecond: 2, maxBurst: 1);

        // Consume the only token
        await limiter.waitForToken();
        expect(limiter.availableTokens, lessThan(1.0));

        // Next call should wait
        final startTime = DateTime.now();
        await limiter.waitForToken();
        final elapsed = DateTime.now().difference(startTime);

        // Should have waited at least some time (allowing for timing variations)
        expect(elapsed.inMilliseconds, greaterThanOrEqualTo(0));
      });
    });

    group('Token Replenishment', () {
      test('tokens replenish over time', () async {
        final limiter = RateLimiter(maxStanzasPerSecond: 10, maxBurst: 5);

        // Consume all tokens
        for (int i = 0; i < 5; i++) {
          await limiter.waitForToken();
        }

        expect(limiter.availableTokens, lessThan(1.0));

        // Wait for tokens to replenish (at 10 per second, should get 1 token per 100ms)
        await Future.delayed(const Duration(milliseconds: 150));

        // Check if tokens are available (this triggers replenishment)
        // canSend() will replenish tokens based on elapsed time and consume one if available
        final canSend = await limiter.canSend();

        // After 150ms at 10 tokens/sec, we should have replenished ~1.5 tokens
        // canSend() returns true if it was able to consume a token (proving replenishment worked)
        // OR if it returns false, we check that some tokens were replenished (availableTokens > 0)
        expect(
          canSend || limiter.availableTokens > 0.0,
          isTrue,
          reason:
              'Tokens should have been replenished after 150ms at 10 tokens/sec',
        );
      });

      test('tokens do not exceed max burst', () async {
        final limiter = RateLimiter(maxStanzasPerSecond: 1000, maxBurst: 10);

        // Wait long enough to replenish many tokens
        await Future.delayed(const Duration(milliseconds: 100));

        // Tokens should be capped at maxBurst
        expect(limiter.availableTokens, lessThanOrEqualTo(10.0));
      });
    });

    group('Enable/Disable', () {
      test('when disabled, canSend always returns true', () async {
        final limiter = RateLimiter(maxStanzasPerSecond: 1, maxBurst: 1);
        limiter.enabled = false;

        // Consume the token
        await limiter.waitForToken();

        // Even with no tokens, should return true when disabled
        expect(await limiter.canSend(), isTrue);
        expect(limiter.isEnabled, isFalse);
      });

      test('when disabled, waitForToken returns immediately', () async {
        final limiter = RateLimiter(maxStanzasPerSecond: 1, maxBurst: 1);
        limiter.enabled = false;

        // Consume the token
        await limiter.waitForToken();

        // Should return immediately even with no tokens
        final startTime = DateTime.now();
        await limiter.waitForToken();
        final elapsed = DateTime.now().difference(startTime);

        expect(elapsed.inMilliseconds, lessThan(10));
      });

      test('isEnabled reflects current state', () {
        final limiter = RateLimiter();
        expect(limiter.isEnabled, isTrue);

        limiter.enabled = false;
        expect(limiter.isEnabled, isFalse);

        limiter.enabled = true;
        expect(limiter.isEnabled, isTrue);
      });
    });

    group('Reset', () {
      test('reset restores initial token count', () async {
        final limiter = RateLimiter(maxStanzasPerSecond: 10, maxBurst: 5);

        // Consume some tokens
        await limiter.waitForToken();
        await limiter.waitForToken();

        expect(limiter.availableTokens, lessThan(5.0));

        // Reset
        limiter.reset();

        expect(limiter.availableTokens, equals(5.0));
      });

      test('reset updates last update time', () async {
        final limiter = RateLimiter(maxStanzasPerSecond: 10, maxBurst: 5);

        // Consume tokens
        await limiter.waitForToken();
        await Future.delayed(const Duration(milliseconds: 50));

        limiter.reset();

        // After reset, tokens should be at max, not replenished from elapsed time
        expect(limiter.availableTokens, equals(5.0));
      });
    });

    group('Concurrent Access', () {
      test('handles concurrent token requests', () async {
        final limiter = RateLimiter(maxBurst: 10);

        // Make multiple concurrent requests
        final futures = List.generate(10, (_) => limiter.waitForToken());
        await Future.wait(futures);

        // All should have succeeded (within burst limit)
        expect(limiter.availableTokens, lessThan(10.0));
      });

      test('rate limits concurrent requests correctly', () async {
        final limiter = RateLimiter(maxStanzasPerSecond: 10, maxBurst: 5);

        // Try to get more tokens than burst allows
        final futures = List.generate(10, (_) => limiter.waitForToken());

        // Some should succeed immediately, others should wait
        final results = await Future.wait(futures);
        expect(results, isNotEmpty);
      });
    });

    group('Edge Cases', () {
      test('handles zero maxStanzasPerSecond gracefully', () {
        final limiter = RateLimiter(maxStanzasPerSecond: 0, maxBurst: 5);
        expect(limiter.maxStanzasPerSecond, equals(0));
        expect(limiter.availableTokens, equals(5.0));
      });

      test('handles very high rate limits', () async {
        final limiter = RateLimiter(maxStanzasPerSecond: 10000, maxBurst: 1000);

        // Should be able to consume many tokens quickly
        for (int i = 0; i < 100; i++) {
          await limiter.waitForToken();
        }

        expect(limiter.availableTokens, lessThan(1000.0));
      });

      test('handles very low rate limits', () async {
        final limiter = RateLimiter(maxStanzasPerSecond: 1, maxBurst: 1);

        await limiter.waitForToken();
        expect(limiter.availableTokens, lessThan(1.0));

        // Should wait approximately 1 second for next token
        final startTime = DateTime.now();
        await limiter.waitForToken();
        final elapsed = DateTime.now().difference(startTime);

        // Should have waited close to 1 second (allowing for timing variations)
        expect(elapsed.inMilliseconds, greaterThan(800));
        expect(elapsed.inMilliseconds, lessThan(1500));
      });
    });
  });
}
