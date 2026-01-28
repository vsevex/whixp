# CLI Messenger Example

This example demonstrates all the v3.0 features of Whixp in an interactive CLI messaging application.

## Features Demonstrated

### v3.0 Performance Optimizations

- **Message Batching**: Automatically batches outgoing stanzas to reduce network overhead
- **Rate Limiting**: Token bucket algorithm prevents overwhelming the server
- **Bounded Queues**: Configurable queue size limits with backpressure handling
- **Performance Metrics**: Real-time monitoring of client performance

### v3.0 Architecture Changes

- **Non-Singleton Transport**: Each Whixp instance has its own Transport instance
- **Direct Transport Access**: Access `transport.metrics` for performance monitoring

## Usage

```bash
# Basic usage (uses StartTLS by default)
dart run example/cli_messenger.dart <jid> <password> [resource] [options]

# Example
dart run example/cli_messenger.dart user@example.com mypassword desktop

# With auto-refreshing metrics (every 10 seconds)
SHOW_METRICS=1 dart run example/cli_messenger.dart user@example.com mypassword desktop

# For local ejabberd testing (disable TLS)
dart run example/cli_messenger.dart user@localhost mypassword desktop --no-tls

# Use DirectTLS (usually port 5223)
dart run example/cli_messenger.dart user@example.com mypassword desktop --direct-tls

# Accept self-signed certificates (local testing)
dart run example/cli_messenger.dart user@localhost mypassword desktop --accept-bad-cert

# Custom port
dart run example/cli_messenger.dart user@example.com mypassword desktop --port 5223
```

### TLS Options

- `--no-tls`: Disable TLS (plain TCP only) - **ONLY for local testing, NOT secure**
- `--direct-tls`: Use DirectTLS connection (connects with TLS immediately, usually port 5223)
- `--accept-bad-cert`: Accept self-signed or invalid certificates - **ONLY for local testing**
- `--port PORT`: Specify custom port (default: 5222 for StartTLS, 5223 for DirectTLS)

**TLS Configuration Guide**: See [TLS_CONFIGURATION.md](../docs/TLS_CONFIGURATION.md) for detailed information about TLS modes, common errors, and Dart/Flutter limitations.

## Commands

Once connected, you can use the following commands:

- `send <jid> <message>` or `s <jid> <message>` - Send a message to a JID
- `presence [status]` or `p [status]` - Update your presence status
- `metrics` or `m` - Display current performance metrics
- `stats` or `st` - Display detailed performance statistics
- `batching` - Show current batching status
- `help` or `h` or `?` - Show help message
- `quit` or `exit` or `q` - Exit the program

## Example Session

```plain
🚀 Whixp v3.0 CLI Messenger
═══════════════════════════════════════════
Connecting as: user@example.com/desktop

✅ Connected successfully!

💡 Performance Features (v3.0):
   - Message Batching: Enabled
   - Rate Limiting: Enabled
   - Bounded Queues: Enabled
   - Performance Metrics: Available

Available commands:
  send <jid> <message>  - Send a message (alias: s)
  presence [status]     - Update presence (alias: p)
  metrics               - Show performance metrics (alias: m)
  stats                 - Show detailed statistics (alias: st)
  batching              - Show batching status
  help                  - Show this help (alias: h, ?)
  quit                  - Exit the program (alias: exit, q)

whixp> send friend@example.com Hello from Whixp v3.0!
✅ Message queued for friend@example.com

📨 [14:23:45] From: friend@example.com
   Hi! How are you?

whixp> metrics

📊 Performance Metrics
─────────────────────────────────────────
Uptime: 45.2s

Stanzas:
  📤 Sent: 3 (0.1/s)
  📥 Received: 5 (0.1/s)
  🔄 Parsed: 5 (0.1/s)

Batching:
  📦 Current Batch: 0 stanzas
  📊 Batches Flushed: 1
  📈 Avg Batch Size: 2.0
  ⏱️  Avg Flush Time: 1.23ms

Queue:
  📋 Current Size: 0
  📊 Max Size: 1000
  ⚠️  Overflows: 0

Rate Limiting:
  🚦 Rate Limit Hits: 0

Parsing:
  ⚡ Avg Parse Time: 0.456ms
─────────────────────────────────────────

whixp> quit

👋 Disconnected. Goodbye!
```

## Performance Metrics Explained

The metrics command shows:

- **Stanzas**: Count and rate of sent/received/parsed stanzas
- **Batching**: Current batch size, total batches flushed, average batch size and flush time
- **Queue**: Current queue size, maximum size reached, and overflow count
- **Rate Limiting**: Number of times rate limiting was triggered
- **Parsing**: Average time taken to parse incoming XML stanzas

## Notes

- Messages are automatically batched and sent efficiently
- Rate limiting prevents overwhelming the server
- Queue size is bounded to prevent memory issues
- All metrics are tracked in real-time and reset on connection start
