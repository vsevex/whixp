//! Retry / reconnection policy: backoff, max attempts.
//! Config is supplied from Dart; this module applies it on connection failure.

use std::time::Duration;
use tracing::debug;

/// Simple exponential backoff for reconnects.
/// Dart may implement more complex policies; this is the Rust-side executor.
#[derive(Clone, Debug)]
pub struct RetryPolicy {
    pub max_attempts: u32,
    pub initial_delay_ms: u64,
    pub max_delay_ms: u64,
    pub multiplier: f64,
}

impl Default for RetryPolicy {
    fn default() -> Self {
        Self {
            max_attempts: 5,
            initial_delay_ms: 500,
            max_delay_ms: 60_000,
            multiplier: 2.0,
        }
    }
}

impl RetryPolicy {
    pub fn delay_for_attempt(&self, attempt: u32) -> Duration {
        if attempt >= self.max_attempts {
            return Duration::from_millis(self.max_delay_ms);
        }
        let d = (self.initial_delay_ms as f64) * self.multiplier.powi(attempt as i32);
        let d = d.min(self.max_delay_ms as f64);
        Duration::from_millis(d as u64)
    }

    pub fn should_retry(&self, attempt: u32) -> bool {
        attempt < self.max_attempts
    }
}

/// Called when a connection attempt fails; returns next delay or None to stop.
pub fn next_retry_delay(policy: &RetryPolicy, attempt: u32) -> Option<Duration> {
    if !policy.should_retry(attempt) {
        return None;
    }
    let delay = policy.delay_for_attempt(attempt);
    debug!(attempt, delay_ms = delay.as_millis(), "retry scheduled");
    Some(delay)
}
