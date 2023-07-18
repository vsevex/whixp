# 0.0.6 - 2023-07-18

- Added `Disco` extension support.
- Added `Registration` extension support.

## Changed

- Improved WebSocket connectivity for better reliability and performance.
- Enhanced exception handling to provide more informative error messages.

## Deprecated

- N/A

## Removed

- N/A

## Breaking

- `Handler` class implementation changed. `resultCallback` and `errorCallback` methods were added to accept incoming stanzas in an efficient way and used an FP package named `dartz`.

## 0.0.55 - 2023-07-08

- Added Extension Attachment support.
- Added `vCard` support.
- Added `pubsub` support.

### Fixed

- Resolved various bugs that were affecting the stability and performance of the XMPP client.
- Improved error handling and messaging reliability.

## 0.0.5 - 2023-06-07

- Improved WebSocket connectivity for better reliability and performance.
- Enhanced exception handling to provide more informative error messages.
- Expanded the main constructor by adding a new parameter: `debugEnabled`.

## 0.0.1 - 2023-05-31

- Initial release of the `Echo`.
- WebSocket connectivity to XMPP servers.
- Authentication mechanisms including `SASL-SCRAM` with SHA-1, PLAIN, and SHA-256.
- Basic XMPP protocol numbers for reference.
- Utility methods for common XMPP tasks.
- Tested on Openfire XMPP server.
