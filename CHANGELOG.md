# 0.1.0 - 2023-09-14

## Breaking

- **Event System Overhaul**
  The main eventing system has undergone a significant change. Previously, it used a static approach, but now it utilizes the 'EventsEmitter' class for event handling. This change may require updates to your event handling code. Please refer to the updated documentation for guidance on using the new event system.

## Deprecated

- **Extension Systems and Extensions Removal**
  The previously created extension systems and extensions have been deprecated in this release and will be entirely removed in the next release. It is recommended to prepare for this change by migrating your extensions to the new system that will be introduced in the upcoming version. Detailed instructions will be provided in the next release's documentation.

## 0.0.7 - 2023-08-08

- Added `CAPS` extension support.
- Added `Roster` extension support.

## 0.0.6 - 2023-07-18

- Added `Disco` extension support.
- Added `Registration` extension support.

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

- Initial release of the `EchoX`.
- WebSocket connectivity to XMPP servers.
- Authentication mechanisms including `SASL-SCRAM` with SHA-1, PLAIN, and SHA-256.
- Basic XMPP protocol numbers for reference.
- Utility methods for common XMPP tasks.
- Tested on Openfire XMPP server.
