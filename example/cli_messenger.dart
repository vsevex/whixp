#!/usr/bin/env dart
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:whixp/whixp.dart';

/// CLI Messenger Example - Demonstrates Whixp v3.0 Features
///
/// This example showcases:
/// - Non-singleton Transport instances
/// - Performance optimizations (batching, rate limiting, bounded queues)
/// - Performance metrics monitoring
/// - Interactive messaging CLI
/// - Real-time performance statistics

void main(List<String> args) async {
  if (args.length < 2) {
    print(
        'Usage: dart run example/cli_messenger.dart <jid> <password> [resource] [options]');
    print(
        'Example: dart run example/cli_messenger.dart user@example.com password desktop');
    print('');
    print('Options:');
    print(
        '  --no-tls          Disable StartTLS (plain TCP, for local testing)');
    print('  --direct-tls      Use DirectTLS (connect with TLS immediately)');
    print('  --accept-bad-cert Accept self-signed/invalid certificates');
    print(
        '  --port PORT       Specify custom port (default: 5222, DirectTLS: 5223)');
    print('');
    print('Note: JID must be in format user@domain.com (not just username)');
    print('');
    print('TLS Configuration:');
    print('  - Default: Uses StartTLS (plain TCP, then upgrade to TLS)');
    print('  - --no-tls: Plain TCP only (NOT recommended for production)');
    print('  - --direct-tls: Direct TLS connection (usually port 5223)');
    exit(1);
  }

  final jid = args[0];
  final password = args[1];
  final resource = args.length > 2 ? args[2] : 'cli';

  // Parse options (defaults to secure StartTLS)
  bool disableStartTLS = false;
  bool useDirectTLS = false;
  bool acceptBadCert = false;
  int? customPort;

  for (int i = 3; i < args.length; i++) {
    switch (args[i]) {
      case '--no-tls':
        disableStartTLS = true;
      case '--direct-tls':
        useDirectTLS = true;
      case '--accept-bad-cert':
        acceptBadCert = true;
      case '--port':
        if (i + 1 < args.length) {
          customPort = int.tryParse(args[i + 1]);
          if (customPort == null) {
            print('❌ Error: Invalid port number: ${args[i + 1]}');
            exit(1);
          }
          i++; // Skip next argument
        }
      default:
        print('❌ Error: Unknown option: ${args[i]}');
        print('Use --help for usage information');
        exit(1);
    }
  }

  // Validate JID format
  if (!jid.contains('@')) {
    print('❌ Error: JID must be in format user@domain.com');
    print('   You provided: $jid');
    print('   Expected format: user@example.com');
    exit(1);
  }

  // Set default port for DirectTLS
  if (useDirectTLS && customPort == null) {
    customPort = 5223; // Standard XMPP DirectTLS port
  }

  print('🚀 Whixp v3.0 CLI Messenger');
  print('═══════════════════════════════════════════');
  print('Connecting as: $jid/$resource');
  print('');

  // Create Whixp instance
  // Note: Performance optimizations are configured at Transport level
  // For this example, we'll use default settings and access metrics
  final whixp = Whixp(
    jabberID: '$jid/$resource',
    password: password,
    port: customPort ?? (useDirectTLS ? 5223 : 5222),
    logger: Log(
      enableWarning: true,
      enableError: true,
      includeTimestamp: true,
    ),
    internalDatabasePath: 'whixp_cli',
    useTLS: useDirectTLS,
    disableStartTLS: disableStartTLS,
    onBadCertificateCallback: acceptBadCert ? (cert) => true : null,
  );

  // Print TLS configuration
  if (disableStartTLS) {
    print('⚠️  WARNING: TLS is disabled (plain TCP only)');
    print('   This is NOT secure and should only be used for local testing!');
    print('');
  } else if (useDirectTLS) {
    print('🔒 Using DirectTLS (port ${customPort ?? 5223})');
    if (acceptBadCert) {
      print('⚠️  WARNING: Accepting invalid certificates (for local testing)');
    }
    print('');
  } else {
    print('🔒 Using StartTLS (default, secure)');
    if (acceptBadCert) {
      print('⚠️  WARNING: Accepting invalid certificates (for local testing)');
    }
    print('');
  }

  // Access Transport to demonstrate v3.0 features
  // In v3.0, Transport is no longer a singleton - each Whixp instance has its own
  // We'll use transport.metrics to demonstrate performance monitoring

  // Setup event handlers
  _setupEventHandlers(whixp);

  // Track connection state
  bool connected = false;
  String? connectionError;
  final connectionCompleter = Completer<void>();

  // Setup connection event handlers before connecting
  whixp.addEventHandler('streamNegotiated', (_) {
    if (!connected) {
      connected = true;
      if (!connectionCompleter.isCompleted) {
        connectionCompleter.complete();
      }
    }
  });

  // Listen for connection failures via state changes
  whixp.addEventHandler<TransportState>('state', (state) {
    if (state == TransportState.connectionFailure) {
      connectionError ??= 'Connection failed - check server and credentials';
      if (!connectionCompleter.isCompleted) {
        connectionCompleter.completeError(connectionError!);
      }
    } else if (state == TransportState.disconnected && !connected) {
      // Only treat as failure if we haven't connected yet
      connectionError ??= 'Connection lost before establishment';
      if (!connectionCompleter.isCompleted) {
        connectionCompleter.completeError(connectionError!);
      }
    }
  });

  whixp.addEventHandler('connectionFailure', (error) {
    connectionError = error?.toString() ?? 'Connection failed';
    if (!connectionCompleter.isCompleted) {
      connectionCompleter.completeError(connectionError!);
    }
  });

  // Connect with error handling
  try {
    whixp.connect();
  } catch (e) {
    print('❌ Failed to initiate connection: $e');
    exit(1);
  }

  // Wait for connection to establish (with timeout)
  try {
    await connectionCompleter.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw TimeoutException(
          'Connection timeout after 15 seconds. '
          'The server may be unreachable or not responding.',
          const Duration(seconds: 15),
        );
      },
    );

    print('✅ Connected successfully!');
    print('');
    _printHelp();
    print('');

    // Start interactive loop
    await _interactiveLoop(whixp);
  } on TimeoutException catch (e) {
    print('❌ $e');
    print('');
    print('Troubleshooting:');
    print('  - Check if the XMPP server is running');
    print('  - Verify the server address and port');
    print('  - Check your network connection');
    exit(1);
  } catch (e) {
    final errorMsg = connectionError ?? e.toString();
    print('❌ Connection error: $errorMsg');
    print('');
    print('Possible issues:');

    // Provide specific guidance based on error type
    if (errorMsg.contains('TLS') ||
        errorMsg.contains('handshake') ||
        errorMsg.contains('WRONG_VERSION_NUMBER')) {
      print('  🔒 TLS/SSL Handshake Failed:');
      print('     - Server may not support the requested TLS mode');
      print('     - Port mismatch (StartTLS uses 5222, DirectTLS uses 5223)');
      print('     - Certificate validation failed');
      print('');
      print('  💡 Solutions for local ejabberd:');
      print('     - Try: --no-tls (disables TLS, plain TCP only)');
      print('     - Or: --direct-tls --port 5223 (if ejabberd has DirectTLS)');
      print('     - Or: --accept-bad-cert (accepts self-signed certificates)');
      print('     - Check ejabberd config: listen -> starttls_required: false');
    } else {
      print('  - Server is unreachable or not responding');
      print('  - Incorrect server address or port');
      print('  - Network connectivity issues');
      print('  - Server requires different TLS configuration');
    }
    print('');
    print('Dart/Flutter TLS Limitations:');
    print('  - Supports TLSv1.2 and TLSv1.3 (configured in Transport)');
    print('  - Certificate validation follows platform defaults');
    print('  - Self-signed certificates require onBadCertificateCallback');
    print('  - Some older TLS versions may not be supported');
    exit(1);
  } finally {
    try {
      await whixp.disconnect();
    } catch (_) {
      // Ignore disconnect errors
    }
    print('\n👋 Disconnected. Goodbye!');
  }
}

void _setupEventHandlers(Whixp whixp) {
  // Connection events (streamNegotiated is handled in main)
  whixp.addEventHandler('sessionStarted', (_) {
    print('🎉 Session started!');
    whixp.sendPresence();
  });

  // Message handling
  whixp.addEventHandler<Message>('message', (message) {
    if (message == null) return;

    final from = message.from?.username ?? 'unknown';
    final body = message.body ?? '(no body)';
    final timestamp = DateTime.now().toString().substring(11, 19);

    print('');
    print('📨 [$timestamp] From: $from');
    print('   $body');
    print('');
  });

  // Error handling
  whixp.addEventHandler('connectionLost', (_) {
    print('⚠️  Connection lost. Attempting to reconnect...');
  });

  whixp.addEventHandler('connectionFailed', (error) {
    print('❌ Connection failed: $error');
  });
}

Future<void> _interactiveLoop(Whixp whixp) async {
  final transport = whixp.transport;

  print('💡 Performance Features (v3.0):');
  print('   - Message Batching: Enabled');
  print('   - Rate Limiting: Enabled');
  print('   - Bounded Queues: Enabled');
  print('   - Performance Metrics: Available');
  print('');

  // Start metrics display timer
  Timer? metricsTimer;
  if (Platform.environment.containsKey('SHOW_METRICS')) {
    metricsTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _printMetrics(transport.metrics);
    });
  }

  // IMPORTANT: Do not use stdin.readLineSync() here.
  // It blocks the event loop and can prevent Whixp's async send pipeline
  // (including XEP-0198 persistence) from making progress.
  stdout.write('whixp> ');
  await stdout.flush();

  await for (final line
      in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.trim().isEmpty) {
      stdout.write('whixp> ');
      await stdout.flush();
      continue;
    }

    final parts = line.trim().split(' ');
    final command = parts[0].toLowerCase();

    try {
      switch (command) {
        case 'send':
        case 's':
          if (parts.length < 3) {
            print('Usage: send <jid> <message>');
            break;
          }
          final toJid = parts[1];
          final messageText = parts.sublist(2).join(' ');
          whixp.sendMessage(JabberID(toJid), body: messageText);
          print('✅ Message queued for $toJid');
        case 'presence':
        case 'p':
          final status = parts.length > 1 ? parts.sublist(1).join(' ') : null;
          whixp.sendPresence(status: status);
          print('✅ Presence updated');
        case 'metrics':
        case 'm':
          _printMetrics(transport.metrics);
        case 'stats':
        case 'st':
          _printDetailedStats(transport.metrics);
        case 'batching':
          if (parts.length < 2) {
            print(
                'Batching: ${transport.metrics.currentBatchSize} stanzas in current batch');
            print('Usage: batching <on|off>');
            break;
          }
          // Note: Batching is controlled via Transport constructor
          // This is just for demonstration
          print('Batching is configured at Transport creation');
        case 'help':
        case 'h':
        case '?':
          _printHelp();
        case 'quit':
        case 'exit':
        case 'q':
          metricsTimer?.cancel();
          return;

        default:
          print('Unknown command: $command');
          print('Type "help" for available commands');
      }
    } catch (e) {
      print('❌ Error: $e');
    }

    stdout.write('whixp> ');
    await stdout.flush();
  }
}

void _printHelp() {
  print('Available commands:');
  print('  send <jid> <message>  - Send a message (alias: s)');
  print('  presence [status]     - Update presence (alias: p)');
  print('  metrics               - Show performance metrics (alias: m)');
  print('  stats                 - Show detailed statistics (alias: st)');
  print('  batching              - Show batching status');
  print('  help                  - Show this help (alias: h, ?)');
  print('  quit                  - Exit the program (alias: exit, q)');
  print('');
  print('Performance Features (v3.0):');
  print('  - Message batching: Enabled (reduces network overhead)');
  print('  - Rate limiting: Enabled (prevents server overload)');
  print('  - Bounded queues: Enabled (memory management)');
  print('  - Performance metrics: Available via "metrics" command');
  print('');
  print(
      'Set SHOW_METRICS=1 environment variable to auto-display metrics every 10s');
}

void _printMetrics(PerformanceMetrics metrics) {
  final summary = metrics.getSummary();
  print('');
  print('📊 Performance Metrics');
  print('─────────────────────────────────────────');
  print('Uptime: ${(summary['uptimeSeconds'] as double).toStringAsFixed(1)}s');
  print('');
  print('Stanzas:');
  print('  📤 Sent: ${summary['stanzasSent']} '
      '(${(summary['stanzasPerSecondSent'] as double).toStringAsFixed(1)}/s)');
  print('  📥 Received: ${summary['stanzasReceived']} '
      '(${(summary['stanzasPerSecondReceived'] as double).toStringAsFixed(1)}/s)');
  print('  🔄 Parsed: ${summary['stanzasParsed']} '
      '(${(summary['stanzasPerSecondParsed'] as double).toStringAsFixed(1)}/s)');
  print('');
  print('Batching:');
  print('  📦 Current Batch: ${summary['currentBatchSize']} stanzas');
  print('  📊 Batches Flushed: ${summary['batchesFlushed']}');
  print(
      '  📈 Avg Batch Size: ${(summary['averageBatchSize'] as double).toStringAsFixed(1)}');
  print(
      '  ⏱️  Avg Flush Time: ${(summary['averageBatchFlushTimeMs'] as double).toStringAsFixed(2)}ms');
  print('');
  print('Queue:');
  print('  📋 Current Size: ${summary['currentQueueSize']}');
  print('  📊 Max Size: ${summary['maxQueueSize']}');
  print('  ⚠️  Overflows: ${summary['queueOverflows']}');
  print('');
  print('Rate Limiting:');
  print('  🚦 Rate Limit Hits: ${summary['rateLimitHits']}');
  print('');
  print('Parsing:');
  print(
      '  ⚡ Avg Parse Time: ${(summary['averageParsingTimeMs'] as double).toStringAsFixed(3)}ms');
  print('─────────────────────────────────────────');
  print('');
}

void _printDetailedStats(PerformanceMetrics metrics) {
  print('');
  print('📈 Detailed Statistics');
  print('═══════════════════════════════════════════');
  print(metrics.getFormattedSummary());
  print('');
}
