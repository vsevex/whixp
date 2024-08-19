import 'dart:async';
import 'dart:math' as math;

import 'package:synchronized/synchronized.dart';

import 'package:whixp/src/log/log.dart';

typedef PerformReconnectFunction = Future<void> Function();

abstract class ReconnectionPolicy {
  /// Function provided by XmppConnection that allows the policy
  /// to perform a reconnection.
  PerformReconnectFunction? performReconnect;

  final Lock _lock = Lock();

  /// Indicate if a reconnection attempt is currently running.
  bool _isReconnecting = false;

  /// Indicate if should try to reconnect.
  bool _shouldAttemptReconnection = false;

  Future<bool> canTryReconnecting() async =>
      _lock.synchronized(() => !_isReconnecting);

  Future<bool> getIsReconnecting() async =>
      _lock.synchronized(() => _isReconnecting);

  Future<void> _resetIsReconnecting() =>
      _lock.synchronized(() => _isReconnecting = false);

  /// In case the policy depends on some internal state, this state must be reset
  /// to an initial state when reset is called. In case timers run, they must be
  /// terminated.
  Future<void> reset() => _resetIsReconnecting();

  Future<bool> canTriggerFailure() => _lock.synchronized(() {
        if (_shouldAttemptReconnection && !_isReconnecting) {
          _isReconnecting = true;
          return true;
        }

        return false;
      });

  /// Called by the XmppConnection when the reconnection failed.
  Future<void> onFailure() async {}

  /// Caled by the XmppConnection when the reconnection was successful.
  Future<void> onSuccess();

  Future<bool> getShouldReconnect() async {
    return _lock.synchronized(() => _shouldAttemptReconnection);
  }

  /// Set whether a reconnection attempt should be made.
  Future<void> setShouldReconnect(bool value) =>
      _lock.synchronized(() => _shouldAttemptReconnection = value);
}

/// A simple reconnection strategy: Make the reconnection delays exponentially
/// longer for every failed attempt.
class RandomBackoffReconnectionPolicy extends ReconnectionPolicy {
  RandomBackoffReconnectionPolicy(
    this._minBackoffTime,
    this._maxBackoffTime,
  )   : assert(
          _minBackoffTime < _maxBackoffTime,
          '_minBackoffTime must be smaller than _maxBackoffTime',
        ),
        super();

  /// The maximum time in seconds that a backoff should be.
  final int _maxBackoffTime;

  /// The minimum time in seconds that a backoff should be.
  final int _minBackoffTime;

  /// Backoff timer.
  Timer? _timer;

  /// Logger.
  final Lock _timerLock = Lock();

  /// Called when the backoff expired
  Future<void> onTimerElapsed() async {
    Log.instance.info('Timer elapsed. Waiting for lock...');
    final shouldContinue = await _timerLock.synchronized(() async {
      if (_timer == null) {
        Log.instance
            .warning('The timer is already set to null. Doing nothing.');
        return false;
      }

      if (!(await getIsReconnecting())) return false;

      if (!(await getShouldReconnect())) return false;

      _timer?.cancel();
      _timer = null;
      return true;
    });

    if (!shouldContinue) return;

    Log.instance.info('Reconnecting...');
    await performReconnect!();
  }

  @override
  Future<void> reset() async {
    Log.instance.info('Resetting reconnection policy');
    await _timerLock.synchronized(() {
      _timer?.cancel();
      _timer = null;
    });
    await super.reset();
  }

  @override
  Future<void> onFailure() async {
    final seconds = math.Random().nextInt(_maxBackoffTime - _minBackoffTime) +
        _minBackoffTime;
    Log.instance
        .info('Failure occured. Starting random backoff with ${seconds}s');

    await _timerLock.synchronized(() {
      _timer?.cancel();
      _timer = Timer(Duration(seconds: seconds), onTimerElapsed);
    });
  }

  @override
  Future<void> onSuccess() async {
    await reset();
  }

  bool isTimerRunning() => _timer != null;
}
