import 'dart:async' as async;

import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/mixins.dart';

/// Batches outgoing stanzas to reduce network overhead and improve performance.
///
/// Instead of sending each stanza individually, the batcher collects multiple
/// stanzas and sends them together, reducing the number of network operations.
class MessageBatcher {
  /// Creates a [MessageBatcher] with the specified configuration.
  MessageBatcher({
    /// Maximum number of stanzas to batch before flushing
    this.maxBatchSize = 50,

    /// Maximum time (in milliseconds) to wait before flushing a batch
    this.maxBatchDelay = 100,

    /// Callback to send batched stanzas
    required this.onFlush,
  });

  /// Maximum number of stanzas to batch before automatically flushing
  final int maxBatchSize;

  /// Maximum time in milliseconds to wait before flushing a batch
  final int maxBatchDelay;

  /// Callback function that receives batched stanzas to send
  final void Function(List<Packet> batch) onFlush;

  /// Current batch of stanzas waiting to be sent
  final List<Packet> _batch = [];

  /// Timer for delayed flushing
  async.Timer? _flushTimer;

  /// Lock to ensure thread-safe batching operations
  bool _locked = false;

  /// Whether batching is currently enabled
  bool _enabled = true;

  /// Whether the batcher is currently flushing
  bool _isFlushing = false;

  /// Adds a packet to the current batch.
  ///
  /// If the batch reaches [maxBatchSize], it will be flushed immediately.
  /// Otherwise, a timer is set to flush after [maxBatchDelay] milliseconds.
  Future<void> add(Packet packet) async {
    if (!_enabled) {
      // If batching is disabled, send immediately
      onFlush([packet]);
      return;
    }

    // Critical stanzas (IQ, SASL, SM) should not be batched
    if (_shouldSendImmediately(packet)) {
      // Flush current batch first if it exists
      await _flushIfNeeded();
      // Send critical packet immediately
      onFlush([packet]);
      return;
    }

    while (_locked) {
      await async.Future.delayed(Duration.zero);
    }
    _locked = true;
    _batch.add(packet);
    _locked = false;

    // Flush if batch is full
    if (_batch.length >= maxBatchSize) {
      await _flush();
    } else {
      // Set timer for delayed flush if not already set
      _flushTimer ??= async.Timer(
        Duration(milliseconds: maxBatchDelay),
        _flush,
      );
    }
  }

  /// Determines if a packet should be sent immediately without batching.
  bool _shouldSendImmediately(Packet packet) {
    // IQ stanzas need immediate responses
    if (packet is IQ) return true;

    // SASL and Stream Management packets are critical
    if (packet.name.startsWith('sasl') || packet.name.startsWith('sm')) {
      return true;
    }

    // Session establishment packets
    switch (packet.name) {
      case 'proceed':
      case 'bind':
      case 'session':
      case 'register':
        return true;
      default:
        return false;
    }
  }

  /// Flushes the current batch if it contains any packets.
  Future<void> _flushIfNeeded() async {
    if (_batch.isNotEmpty && !_isFlushing) {
      await _flush();
    }
  }

  /// Flushes the current batch, sending all accumulated packets.
  Future<void> _flush() async {
    if (_isFlushing || _batch.isEmpty) return;

    _isFlushing = true;
    _flushTimer?.cancel();
    _flushTimer = null;

    final batchToSend = List<Packet>.from(_batch);
    _batch.clear();

    _isFlushing = false;

    if (batchToSend.isNotEmpty) {
      Log.instance.debug(
        'Flushing batch of ${batchToSend.length} stanzas',
      );
      onFlush(batchToSend);
    }
  }

  /// Manually flushes the current batch.
  ///
  /// Useful when you need to ensure all pending stanzas are sent immediately.
  Future<void> flush() => _flush();

  /// Enables or disables batching.
  ///
  /// When disabled, packets are sent immediately without batching.
  void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!enabled) {
      // Flush any pending batch when disabling
      _flush();
    }
  }

  /// Returns the current batch size.
  int get currentBatchSize => _batch.length;

  /// Returns whether batching is enabled.
  bool get isEnabled => _enabled;

  /// Disposes of the batcher, flushing any remaining packets.
  Future<void> dispose() async {
    _enabled = false;
    _flushTimer?.cancel();
    await _flush();
  }
}
