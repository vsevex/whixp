/// Performance metrics for monitoring XMPP client performance.
///
/// Tracks various metrics including stanzas sent/received, parsing times,
/// batch statistics, rate limiter usage, and queue sizes.
class PerformanceMetrics {
  /// Creates a [PerformanceMetrics] instance.
  PerformanceMetrics() {
    _resetCounters();
  }

  // Counters
  int _stanzasSent = 0;
  int _stanzasReceived = 0;
  int _stanzasParsed = 0;
  int _batchesFlushed = 0;
  int _rateLimitHits = 0;
  int _queueOverflows = 0;

  // Timing metrics
  final List<Duration> _parsingTimes = [];
  final List<Duration> _batchFlushTimes = [];
  final List<int> _batchSizes = [];

  // Current state
  int _currentQueueSize = 0;
  int _maxQueueSize = 0;
  int _currentBatchSize = 0;
  int _maxBatchSize = 0;

  // Timestamps
  DateTime? _startTime;
  DateTime? _lastResetTime;

  /// Resets all counters and metrics.
  void reset() {
    _resetCounters();
    _startTime = DateTime.now();
    _lastResetTime = DateTime.now();
  }

  void _resetCounters() {
    _stanzasSent = 0;
    _stanzasReceived = 0;
    _stanzasParsed = 0;
    _batchesFlushed = 0;
    _rateLimitHits = 0;
    _queueOverflows = 0;
    _parsingTimes.clear();
    _batchFlushTimes.clear();
    _batchSizes.clear();
    _currentQueueSize = 0;
    _maxQueueSize = 0;
    _currentBatchSize = 0;
    _maxBatchSize = 0;
  }

  /// Records a stanza being sent.
  void recordStanzaSent() => _stanzasSent++;

  /// Records a stanza being received.
  void recordStanzaReceived() => _stanzasReceived++;

  /// Records a stanza being parsed with the time taken.
  void recordStanzaParsed(Duration parsingTime) {
    _stanzasParsed++;
    _parsingTimes.add(parsingTime);
    // Keep only last 1000 parsing times to avoid memory issues
    if (_parsingTimes.length > 1000) {
      _parsingTimes.removeAt(0);
    }
  }

  /// Records a batch being flushed with size and time taken.
  void recordBatchFlushed(int batchSize, Duration flushTime) {
    _batchesFlushed++;
    _batchSizes.add(batchSize);
    _batchFlushTimes.add(flushTime);
    // Keep only last 100 batch statistics
    if (_batchSizes.length > 100) {
      _batchSizes.removeAt(0);
      _batchFlushTimes.removeAt(0);
    }
  }

  /// Records a rate limit hit.
  void recordRateLimitHit() => _rateLimitHits++;

  /// Records a queue overflow.
  void recordQueueOverflow() => _queueOverflows++;

  /// Updates the current queue size.
  void updateQueueSize(int size) {
    _currentQueueSize = size;
    if (size > _maxQueueSize) {
      _maxQueueSize = size;
    }
  }

  /// Updates the current batch size.
  void updateBatchSize(int size) {
    _currentBatchSize = size;
    if (size > _maxBatchSize) {
      _maxBatchSize = size;
    }
  }

  // Getters for metrics

  /// Total number of stanzas sent.
  int get stanzasSent => _stanzasSent;

  /// Total number of stanzas received.
  int get stanzasReceived => _stanzasReceived;

  /// Total number of stanzas parsed.
  int get stanzasParsed => _stanzasParsed;

  /// Total number of batches flushed.
  int get batchesFlushed => _batchesFlushed;

  /// Total number of rate limit hits.
  int get rateLimitHits => _rateLimitHits;

  /// Total number of queue overflows.
  int get queueOverflows => _queueOverflows;

  /// Current queue size.
  int get currentQueueSize => _currentQueueSize;

  /// Maximum queue size reached.
  int get maxQueueSize => _maxQueueSize;

  /// Current batch size.
  int get currentBatchSize => _currentBatchSize;

  /// Maximum batch size reached.
  int get maxBatchSize => _maxBatchSize;

  /// Average parsing time in milliseconds.
  double get averageParsingTimeMs {
    if (_parsingTimes.isEmpty) return 0.0;
    final totalMs = _parsingTimes
        .map((d) => d.inMicroseconds / 1000.0)
        .fold(0.0, (a, b) => a + b);
    return totalMs / _parsingTimes.length;
  }

  /// Average batch size.
  double get averageBatchSize {
    if (_batchSizes.isEmpty) return 0.0;
    final total = _batchSizes.fold(0, (a, b) => a + b);
    return total / _batchSizes.length;
  }

  /// Average batch flush time in milliseconds.
  double get averageBatchFlushTimeMs {
    if (_batchFlushTimes.isEmpty) return 0.0;
    final totalMs = _batchFlushTimes
        .map((d) => d.inMicroseconds / 1000.0)
        .fold(0.0, (a, b) => a + b);
    return totalMs / _batchFlushTimes.length;
  }

  /// Stanzas sent per second (calculated since last reset).
  double get stanzasPerSecondSent {
    final elapsed = _getElapsedSeconds();
    if (elapsed == 0) return 0.0;
    return _stanzasSent / elapsed;
  }

  /// Stanzas received per second (calculated since last reset).
  double get stanzasPerSecondReceived {
    final elapsed = _getElapsedSeconds();
    if (elapsed == 0) return 0.0;
    return _stanzasReceived / elapsed;
  }

  /// Stanzas parsed per second (calculated since last reset).
  double get stanzasPerSecondParsed {
    final elapsed = _getElapsedSeconds();
    if (elapsed == 0) return 0.0;
    return _stanzasParsed / elapsed;
  }

  double _getElapsedSeconds() {
    final start = _startTime ?? _lastResetTime ?? DateTime.now();
    final now = DateTime.now();
    return now.difference(start).inMilliseconds / 1000.0;
  }

  /// Gets a summary of all metrics as a map.
  Map<String, dynamic> getSummary() => {
        'stanzasSent': _stanzasSent,
        'stanzasReceived': _stanzasReceived,
        'stanzasParsed': _stanzasParsed,
        'batchesFlushed': _batchesFlushed,
        'rateLimitHits': _rateLimitHits,
        'queueOverflows': _queueOverflows,
        'currentQueueSize': _currentQueueSize,
        'maxQueueSize': _maxQueueSize,
        'currentBatchSize': _currentBatchSize,
        'maxBatchSize': _maxBatchSize,
        'averageParsingTimeMs': averageParsingTimeMs,
        'averageBatchSize': averageBatchSize,
        'averageBatchFlushTimeMs': averageBatchFlushTimeMs,
        'stanzasPerSecondSent': stanzasPerSecondSent,
        'stanzasPerSecondReceived': stanzasPerSecondReceived,
        'stanzasPerSecondParsed': stanzasPerSecondParsed,
        'uptimeSeconds': _getElapsedSeconds(),
      };

  /// Gets a formatted string summary of metrics.
  String getFormattedSummary() {
    final summary = getSummary();
    final buffer = StringBuffer();
    buffer.writeln('=== Performance Metrics ===');
    buffer.writeln(
        'Uptime: ${(summary['uptimeSeconds'] as double).toStringAsFixed(2)}s');
    buffer.writeln();
    buffer.writeln('Stanzas:');
    buffer.writeln(
        '  Sent: ${summary['stanzasSent']} (${(summary['stanzasPerSecondSent'] as double).toStringAsFixed(2)}/s)');
    buffer.writeln(
        '  Received: ${summary['stanzasReceived']} (${(summary['stanzasPerSecondReceived'] as double).toStringAsFixed(2)}/s)');
    buffer.writeln(
        '  Parsed: ${summary['stanzasParsed']} (${(summary['stanzasPerSecondParsed'] as double).toStringAsFixed(2)}/s)');
    buffer.writeln();
    buffer.writeln('Batching:');
    buffer.writeln('  Batches Flushed: ${summary['batchesFlushed']}');
    buffer.writeln('  Current Batch Size: ${summary['currentBatchSize']}');
    buffer.writeln('  Max Batch Size: ${summary['maxBatchSize']}');
    buffer.writeln(
        '  Average Batch Size: ${(summary['averageBatchSize'] as double).toStringAsFixed(2)}');
    buffer.writeln(
        '  Average Flush Time: ${(summary['averageBatchFlushTimeMs'] as double).toStringAsFixed(2)}ms');
    buffer.writeln();
    buffer.writeln('Queue:');
    buffer.writeln('  Current Size: ${summary['currentQueueSize']}');
    buffer.writeln('  Max Size: ${summary['maxQueueSize']}');
    buffer.writeln('  Overflows: ${summary['queueOverflows']}');
    buffer.writeln();
    buffer.writeln('Rate Limiting:');
    buffer.writeln('  Rate Limit Hits: ${summary['rateLimitHits']}');
    buffer.writeln();
    buffer.writeln('Parsing:');
    buffer.writeln(
        '  Average Time: ${(summary['averageParsingTimeMs'] as double).toStringAsFixed(2)}ms');
    buffer.writeln('===========================');
    return buffer.toString();
  }
}
