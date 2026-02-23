import 'dart:async' as async;

import 'package:whixp/src/log/log.dart';

/// Rate limiter to prevent overwhelming the XMPP server with too many requests.
///
/// Implements a token bucket algorithm to control the rate of outgoing stanzas.
class RateLimiter {
  /// Creates a [RateLimiter] with the specified configuration.
  RateLimiter({
    /// Maximum number of stanzas allowed per second
    this.maxStanzasPerSecond = 100,

    /// Maximum burst size (number of stanzas that can be sent immediately)
    this.maxBurst = 50,
  }) : _tokens = maxBurst.toDouble();

  /// Maximum number of stanzas allowed per second
  final int maxStanzasPerSecond;

  /// Maximum burst size
  final int maxBurst;

  /// Current number of available tokens
  double _tokens = 0;

  /// Last time tokens were replenished
  DateTime _lastUpdate = DateTime.now();

  /// Lock to ensure thread-safe operations
  bool _locked = false;

  /// Whether rate limiting is enabled
  bool enabled = true;

  /// Checks if a stanza can be sent immediately or needs to wait.
  ///
  /// Returns `true` if the stanza can be sent, `false` if rate limiting is active.
  Future<bool> canSend() async {
    if (!enabled) return true;

    // Simple lock mechanism
    while (_locked) {
      await async.Future.delayed(const Duration(milliseconds: 1));
    }
    _locked = true;
    _replenishTokens();

    if (_tokens >= 1.0) {
      _tokens -= 1.0;
      _locked = false;
      return true;
    }

    _locked = false;
    return false;
  }

  /// Waits until a token is available, then consumes it.
  ///
  /// This method will block until rate limiting allows sending.
  Future<void> waitForToken() async {
    if (!enabled) return;

    while (true) {
      while (_locked) {
        await async.Future.delayed(Duration.zero);
      }
      _locked = true;
      _replenishTokens();

      if (_tokens >= 1.0) {
        _tokens -= 1.0;
        _locked = false;
        return;
      }
      _locked = false;

      // Calculate wait time until next token is available
      final tokensNeeded = 1.0 - _tokens;
      final waitSeconds = tokensNeeded / maxStanzasPerSecond;
      final waitMilliseconds = (waitSeconds * 1000).ceil();

      if (waitMilliseconds > 0) {
        Log.instance.debug(
          'Rate limit: waiting ${waitMilliseconds}ms for token',
        );
        await async.Future.delayed(Duration(milliseconds: waitMilliseconds));
      }
    }
  }

  /// Replenishes tokens based on elapsed time.
  void _replenishTokens() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastUpdate).inMilliseconds / 1000.0;

    if (elapsed > 0) {
      // Add tokens based on elapsed time
      _tokens = (_tokens + elapsed * maxStanzasPerSecond)
          .clamp(0.0, maxBurst.toDouble());
      _lastUpdate = now;
    }
  }

  /// Returns the current number of available tokens.
  double get availableTokens => _tokens;

  /// Returns whether rate limiting is enabled.
  bool get isEnabled => enabled;

  /// Resets the rate limiter to its initial state.
  void reset() {
    _tokens = maxBurst.toDouble();
    _lastUpdate = DateTime.now();
  }
}
