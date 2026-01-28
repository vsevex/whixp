import 'package:test/test.dart';

import 'package:whixp/src/log/log.dart';
import 'package:whixp/src/performance/batcher.dart';
import 'package:whixp/src/stanza/iq.dart';
import 'package:whixp/src/stanza/message.dart';
import 'package:whixp/src/stanza/mixins.dart';
import 'package:whixp/src/stanza/stanza.dart';
import 'package:xml/xml.dart' as xml;

void main() {
  setUp(() {
    // Initialize Log singleton before each test
    Log(
      enableDebug: false,
      enableInfo: false,
    );
  });

  group('MessageBatcher', () {
    test('initializes with default values', () {
      final batcher = MessageBatcher(onFlush: (_) {});

      expect(batcher.maxBatchSize, equals(50));
      expect(batcher.maxBatchDelay, equals(100));
      expect(batcher.isEnabled, isTrue);
      expect(batcher.currentBatchSize, equals(0));
    });

    test('initializes with custom values', () {
      final batcher = MessageBatcher(
        maxBatchSize: 20,
        maxBatchDelay: 50,
        onFlush: (_) {},
      );

      expect(batcher.maxBatchSize, equals(20));
      expect(batcher.maxBatchDelay, equals(50));
    });

    group('Batching Behavior', () {
      test('batches multiple packets', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 5,
          maxBatchDelay: 1000, // Long delay to prevent auto-flush
          onFlush: (List<Packet> batch) => flushedBatches.add(batch),
        );

        // Add multiple packets
        final message1 = Message(body: 'test1');
        final message2 = Message(body: 'test2');
        final message3 = Message(body: 'test3');

        await batcher.add(message1);
        await batcher.add(message2);
        await batcher.add(message3);

        expect(batcher.currentBatchSize, equals(3));
        expect(flushedBatches, isEmpty);

        // Manually flush
        await batcher.flush();

        expect(flushedBatches.length, equals(1));
        expect(flushedBatches.first.length, equals(3));
        expect(batcher.currentBatchSize, equals(0));
      });

      test('auto-flushes when batch size is reached', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 3,
          maxBatchDelay: 1000, // Long delay
          onFlush: (batch) => flushedBatches.add(batch),
        );

        // Add packets up to batch size
        await batcher.add(Message(body: 'test1'));
        await batcher.add(Message(body: 'test2'));
        await batcher.add(Message(body: 'test3'));

        // Should auto-flush
        await Future.delayed(const Duration(milliseconds: 50));

        expect(flushedBatches.length, equals(1));
        expect(flushedBatches.first.length, equals(3));
        expect(batcher.currentBatchSize, equals(0));
      });

      test('auto-flushes after delay', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 10, // Large batch size
          onFlush: (batch) => flushedBatches.add(batch),
        );

        await batcher.add(Message(body: 'test1'));

        // Should flush after delay
        await Future.delayed(const Duration(milliseconds: 150));

        expect(flushedBatches.length, equals(1));
        expect(flushedBatches.first.length, equals(1));
      });
    });

    group('Critical Packet Handling', () {
      test('IQ packets are sent immediately', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 10,
          maxBatchDelay: 1000,
          onFlush: (batch) => flushedBatches.add(batch),
        );

        // Add a regular message
        await batcher.add(Message(body: 'test'));
        expect(batcher.currentBatchSize, equals(1));

        // Add an IQ packet - should flush batch and send IQ immediately
        final iq = IQ()..type = 'get';
        await batcher.add(iq);

        // Should have flushed the batch, then sent IQ
        await Future.delayed(const Duration(milliseconds: 50));

        expect(flushedBatches.length, greaterThanOrEqualTo(1));
        // Last flush should be the IQ alone
        expect(flushedBatches.last.length, equals(1));
        expect(flushedBatches.last.first, equals(iq));
        expect(batcher.currentBatchSize, equals(0));
      });

      test('SASL packets are sent immediately', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 10,
          maxBatchDelay: 1000,
          onFlush: (batch) => flushedBatches.add(batch),
        );

        await batcher.add(Message(body: 'test'));

        // Create a mock SASL packet
        final saslPacket = _MockPacket('sasl-auth');
        await batcher.add(saslPacket);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(flushedBatches.length, greaterThanOrEqualTo(1));
        expect(flushedBatches.last.length, equals(1));
        expect(flushedBatches.last.first.name, equals('sasl-auth'));
      });

      test('SM packets are sent immediately', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 10,
          maxBatchDelay: 1000,
          onFlush: (batch) => flushedBatches.add(batch),
        );

        await batcher.add(Message(body: 'test'));

        final smPacket = _MockPacket('sm-request');
        await batcher.add(smPacket);

        await Future.delayed(const Duration(milliseconds: 50));

        expect(flushedBatches.length, greaterThanOrEqualTo(1));
        expect(flushedBatches.last.length, equals(1));
        expect(flushedBatches.last.first.name, equals('sm-request'));
      });

      test('session establishment packets are sent immediately', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 10,
          maxBatchDelay: 1000,
          onFlush: (batch) => flushedBatches.add(batch),
        );

        await batcher.add(Message(body: 'test'));

        for (final packetName in ['proceed', 'bind', 'session', 'register']) {
          final packet = _MockPacket(packetName);
          await batcher.add(packet);

          await Future.delayed(const Duration(milliseconds: 10));

          expect(flushedBatches.last.length, equals(1));
          expect(flushedBatches.last.first.name, equals(packetName));
        }
      });
    });

    group('Enable/Disable', () {
      test('when disabled, packets are sent immediately', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 10,
          maxBatchDelay: 1000,
          onFlush: (batch) => flushedBatches.add(batch),
        );

        batcher.setEnabled(false);

        await batcher.add(Message(body: 'test1'));
        await batcher.add(Message(body: 'test2'));

        // Should send immediately, not batch
        expect(flushedBatches.length, equals(2));
        expect(flushedBatches[0].length, equals(1));
        expect(flushedBatches[1].length, equals(1));
        expect(batcher.currentBatchSize, equals(0));
      });

      test('disabling flushes pending batch', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 10,
          maxBatchDelay: 1000,
          onFlush: (batch) => flushedBatches.add(batch),
        );

        await batcher.add(Message(body: 'test1'));
        await batcher.add(Message(body: 'test2'));

        expect(batcher.currentBatchSize, equals(2));

        batcher.setEnabled(false);

        // Should flush pending batch
        await Future.delayed(const Duration(milliseconds: 50));
        expect(flushedBatches.length, equals(1));
        expect(flushedBatches.first.length, equals(2));
      });

      test('isEnabled reflects current state', () {
        final batcher = MessageBatcher(onFlush: (_) {});

        expect(batcher.isEnabled, isTrue);

        batcher.setEnabled(false);
        expect(batcher.isEnabled, isFalse);

        batcher.setEnabled(true);
        expect(batcher.isEnabled, isTrue);
      });
    });

    group('Flush', () {
      test('flush sends all batched packets', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 10,
          maxBatchDelay: 1000,
          onFlush: (batch) => flushedBatches.add(batch),
        );

        await batcher.add(Message(body: 'test1'));
        await batcher.add(Message(body: 'test2'));
        await batcher.add(Message(body: 'test3'));

        expect(batcher.currentBatchSize, equals(3));

        await batcher.flush();

        expect(flushedBatches.length, equals(1));
        expect(flushedBatches.first.length, equals(3));
        expect(batcher.currentBatchSize, equals(0));
      });

      test('flush does nothing when batch is empty', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 10,
          maxBatchDelay: 1000,
          onFlush: (batch) => flushedBatches.add(batch),
        );

        await batcher.flush();

        expect(flushedBatches, isEmpty);
      });

      test('multiple flushes work correctly', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 10,
          maxBatchDelay: 1000,
          onFlush: (batch) => flushedBatches.add(batch),
        );

        await batcher.add(Message(body: 'test1'));
        await batcher.flush();

        await batcher.add(Message(body: 'test2'));
        await batcher.flush();

        expect(flushedBatches.length, equals(2));
        expect(flushedBatches[0].length, equals(1));
        expect(flushedBatches[1].length, equals(1));
      });
    });

    group('Dispose', () {
      test('dispose flushes remaining packets', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 10,
          maxBatchDelay: 1000,
          onFlush: (batch) => flushedBatches.add(batch),
        );

        await batcher.add(Message(body: 'test1'));
        await batcher.add(Message(body: 'test2'));

        expect(batcher.currentBatchSize, equals(2));

        await batcher.dispose();

        expect(flushedBatches.length, equals(1));
        expect(flushedBatches.first.length, equals(2));
        expect(batcher.currentBatchSize, equals(0));
        expect(batcher.isEnabled, isFalse);
      });

      test('dispose cancels flush timer', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 10,
          maxBatchDelay: 1000,
          onFlush: (batch) => flushedBatches.add(batch),
        );

        await batcher.add(Message(body: 'test'));

        await batcher.dispose();

        // Timer should be cancelled, no auto-flush should occur
        await Future.delayed(const Duration(milliseconds: 1100));

        // Should only have the dispose flush, not an auto-flush
        expect(flushedBatches.length, equals(1));
      });
    });

    group('Concurrent Access', () {
      test('handles concurrent adds correctly', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 20,
          maxBatchDelay: 1000,
          onFlush: (batch) => flushedBatches.add(batch),
        );

        // Add packets concurrently
        final futures = List.generate(
          10,
          (i) => batcher.add(Message(body: 'test$i')),
        );
        await Future.wait(futures);

        expect(batcher.currentBatchSize, equals(10));

        await batcher.flush();

        expect(flushedBatches.length, equals(1));
        expect(flushedBatches.first.length, equals(10));
      });
    });

    group('Edge Cases', () {
      test('handles empty batch gracefully', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 10,
          onFlush: (batch) => flushedBatches.add(batch),
        );

        await batcher.flush();
        expect(flushedBatches, isEmpty);
      });

      test('handles very small batch size', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 1,
          maxBatchDelay: 1000,
          onFlush: (batch) => flushedBatches.add(batch),
        );

        await batcher.add(Message(body: 'test1'));
        await Future.delayed(const Duration(milliseconds: 50));

        expect(flushedBatches.length, equals(1));
        expect(flushedBatches.first.length, equals(1));
      });

      test('handles very large batch size', () async {
        final flushedBatches = <List<Packet>>[];
        final batcher = MessageBatcher(
          maxBatchSize: 1000,
          maxBatchDelay: 50,
          onFlush: (batch) => flushedBatches.add(batch),
        );

        await batcher.add(Message(body: 'test'));

        // Should flush after delay, not wait for batch size
        await Future.delayed(const Duration(milliseconds: 100));

        expect(flushedBatches.length, equals(1));
        expect(flushedBatches.first.length, equals(1));
      });
    });
  });
}

/// Mock packet class for testing critical packet detection
class _MockPacket extends Stanza {
  _MockPacket(this._name) : super();

  final String _name;

  @override
  String get name => _name;

  @override
  xml.XmlElement toXML() {
    final builder = xml.XmlBuilder();
    builder.element(_name);
    return builder.buildDocument().rootElement;
  }
}
