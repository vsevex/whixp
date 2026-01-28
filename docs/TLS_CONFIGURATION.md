# TLS Configuration Guide

This document explains TLS/SSL configuration options in Whixp and how to handle common TLS issues, especially for local development.

## TLS Connection Modes

Whixp supports three TLS connection modes:

### 1. StartTLS (Default - Recommended)

- **How it works**: Connects via plain TCP, then upgrades to TLS after XMPP stream negotiation
- **Port**: Usually 5222
- **Configuration**: Default behavior (no special flags needed)
- **Security**: ✅ Secure (encrypted after initial handshake)
- **Use case**: Standard XMPP servers, production environments

```dart
final whixp = Whixp(
  jabberID: 'user@example.com/resource',
  password: 'password',
  // StartTLS is the default - no configuration needed
);
```

### 2. DirectTLS

- **How it works**: Connects directly with TLS from the start
- **Port**: Usually 5223
- **Configuration**: Set `useTLS: true`
- **Security**: ✅ Secure (encrypted from connection start)
- **Use case**: Servers configured for DirectTLS, some enterprise setups

```dart
final whixp = Whixp(
  jabberID: 'user@example.com/resource',
  password: 'password',
  useTLS: true,  // DirectTLS
  port: 5223,   // Standard DirectTLS port
);
```

### 3. Plain TCP (No TLS)

- **How it works**: Plain unencrypted TCP connection
- **Port**: Usually 5222
- **Configuration**: Set `disableStartTLS: true`
- **Security**: ❌ NOT SECURE (unencrypted)
- **Use case**: **ONLY for local development/testing**

```dart
final whixp = Whixp(
  jabberID: 'user@example.com/resource',
  password: 'password',
  disableStartTLS: true,  // Plain TCP - NOT for production!
);
```

## Common TLS Errors and Solutions

### Error: WRONG_VERSION_NUMBER or HandshakeException

**Cause**: TLS protocol mismatch or attempting TLS on a non-TLS port.

**Solutions**:

1. **For local ejabberd testing**:

   ```dart
   // Option 1: Disable TLS (local testing only)
   final whixp = Whixp(
     jabberID: 'user@localhost/resource',
     password: 'password',
     disableStartTLS: true,
   );

   // Option 2: Use DirectTLS on correct port
   final whixp = Whixp(
     jabberID: 'user@localhost/resource',
     password: 'password',
     useTLS: true,
     port: 5223,  // DirectTLS port
   );
   ```

2. **Check ejabberd configuration**:

```yaml
# In ejabberd.yml
listen:
  - port: 5222
    module: ejabberd_c2s
    starttls_required: false # Allow plain TCP for testing
```

### Error: Certificate Validation Failed

**Cause**: Self-signed certificate or certificate doesn't match hostname.

**Solution**: Accept bad certificates (ONLY for local development):

```dart
final whixp = Whixp(
  jabberID: 'user@example.com/resource',
  password: 'password',
  onBadCertificateCallback: (cert) => true,  // Accept any certificate
);
```

**⚠️ WARNING**: Never use `onBadCertificateCallback: (cert) => true` in production!

### Error: Connection Timeout or Connection Refused

**Cause**: Wrong port or server not running.

**Solutions**:

- Check if server is running: `systemctl status ejabberd`
- Verify port: StartTLS uses 5222, DirectTLS uses 5223
- Check firewall settings
- Verify server address (use `localhost` for local testing)

## CLI Messenger TLS Options

The CLI messenger example supports TLS configuration via command-line flags:

```bash
# Default (StartTLS)
dart run example/cli_messenger.dart user@example.com password desktop

# Disable TLS (local testing only)
dart run example/cli_messenger.dart user@localhost password desktop --no-tls

# Use DirectTLS
dart run example/cli_messenger.dart user@example.com password desktop --direct-tls

# Accept bad certificates (local testing)
dart run example/cli_messenger.dart user@localhost password desktop --accept-bad-cert

# Custom port
dart run example/cli_messenger.dart user@example.com password desktop --port 5223

# Combine options
dart run example/cli_messenger.dart user@localhost password desktop \
  --no-tls --accept-bad-cert
```

## Dart/Flutter TLS Limitations

### Supported TLS Versions

- ✅ TLSv1.2 (supported)
- ✅ TLSv1.3 (supported)
- ❌ TLSv1.0 and TLSv1.1 (deprecated, not supported)

### Certificate Validation

- Uses platform's default certificate store
- Self-signed certificates require `onBadCertificateCallback`
- Certificate pinning not directly supported (would need custom implementation)

### Platform-Specific Notes

**Android/iOS**:

- Uses platform's native TLS implementation
- Certificate validation follows system trust store
- No additional configuration needed

**macOS/Windows/Linux**:

- Uses Dart's TLS implementation
- Certificate validation follows system CA store
- Self-signed certificates need explicit acceptance

**Web Platform**:

- ⚠️ **NOT SUPPORTED** - Whixp does not support web platform
- Web sockets have different TLS handling
- Use web-specific XMPP libraries for web applications

## Best Practices

### Production

1. ✅ Always use StartTLS (default) or DirectTLS
2. ✅ Never disable TLS (`disableStartTLS: true`)
3. ✅ Never accept bad certificates in production
4. ✅ Use proper certificates from trusted CAs
5. ✅ Verify certificate hostname matches server

### Local Development

1. ⚠️ Can use `disableStartTLS: true` for testing
2. ⚠️ Can use `onBadCertificateCallback: (cert) => true` for self-signed certs
3. ✅ Document TLS configuration in your code
4. ✅ Use environment variables to switch between dev/prod configs

### Example: Environment-Based Configuration

```dart
final isProduction = Platform.environment['ENV'] == 'production';

final whixp = Whixp(
  jabberID: 'user@example.com/resource',
  password: 'password',
  disableStartTLS: !isProduction,  // Disable only in dev
  onBadCertificateCallback: isProduction
    ? null  // Strict validation in production
    : (cert) => true,  // Accept bad certs in dev
);
```

## Troubleshooting ejabberd Local Setup

### 1. Configure ejabberd for local testing

```yaml
# ejabberd.yml
listen:
  - port: 5222
    module: ejabberd_c2s
    starttls_required: false # Allow plain TCP
    starttls: true # But also support StartTLS
    certfile: "/path/to/cert.pem"

  - port: 5223
    module: ejabberd_c2s
    tls: true # DirectTLS
    certfile: "/path/to/cert.pem"
```

### 2. Generate self-signed certificate (for testing)

```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem \
  -days 365 -nodes -subj "/CN=localhost"
```

### 3. Test connection

```bash
# Test with plain TCP (no TLS)
dart run example/cli_messenger.dart user@localhost password desktop --no-tls

# Test with StartTLS (default)
dart run example/cli_messenger.dart user@localhost password desktop --accept-bad-cert

# Test with DirectTLS
dart run example/cli_messenger.dart user@localhost password desktop \
  --direct-tls --accept-bad-cert
```

## Summary

- **Default (StartTLS)**: Best for production, secure, standard
- **DirectTLS**: Use when server requires it, port 5223
- **Plain TCP**: ONLY for local development, never in production
- **Bad Certificates**: Accept only in development, document clearly
- **Dart/Flutter**: Supports TLSv1.2 and TLSv1.3, uses platform certificate stores
