# 2.1.0 - 2024-08-20

- Removed External Components Support: The external components section has been removed to streamline the core package functionality. If you rely on components, refer to the provided examples and code documentation for updated usage patterns.
- Updated Documentation: Expanded documentation to cover new extension support and breaking changes. Refer to the updated examples for proper implementation of new features and adjustments.

- **Breaking Changes**
  - External Components: The support for external components has been deprecated and removed. If you were using this feature, you will need to refactor your implementation. Updated examples are provided in the documentation to guide you through these changes.\
  - Protocol Extensions: Some existing extensions have undergone refactoring to align with the new architecture. Users should review their implementation of protocol extensions and refer to the updated documentation and examples to ensure compatibility.
  - Connection Management and Stanza Handling: The internal handling of connection states and stanzas has been revised. Users may need to update their event handling logic, particularly around connection re-establishment and custom stanza handling.

- **Deprecated**
  - Legacy vCard Support: The legacy vCard _(vCard-temp)_ support has been deprecated in favor of **vCard4 over PubSub**. Users are encouraged to migrate to the new implementation for better performance and flexibility.

- **Documentation**
  - Migration Guide: Included a migration guide in the documentation to help users transition from older versions to this release.

Ensure that you review the updated examples and documentation to adjust your implementation accordingly. If you encounter any issues, please report them via GitHub, and I will address them promptly.

## 2.0.1 - Partially Stable

- Added support for XMPP components.
- Added extension support to pubsub, pep, vcard-temp, and in-band registration as well as tune, ping, delay, stream management, etc.
- Provided more reliable communication using Dart Sockets.
- Changed certificate assignment from explicit to `dart:io`'s SecureContext
- Provided more Whixp-related examples and use cases.

## 2.0.1-beta1 - 2024-01-23

Everything is changed. I mean, literally everything. Can not even put it all into words, especially in here. So, go ahead and give it a try.

But remember, the package is still in beta and not quite ready for stable usage. Please consider this while exploring the new features and improvements. Your feedbacks and bug reports are highly appreciated to help me refine the package for a stable release.

## 0.1.0 - 2023-09-14

## Breaking

- **Event System Overhaul**
  The main eventing system has undergone a significant change. Previously, it used a static approach, but now it utilizes the 'EventsEmitter' class for event handling. This change may require updates to your event handling code.

  Please refer to the updated documentation for guidance on using the new event system.

## Deprecated

- **Extension Systems and Extensions Removal**
  The previously created extension systems and extensions have been deprecated in this release and will be entirely removed in the next release.

  It is recommended to prepare for this change by migrating your extensions to the new system that will be introduced in the upcoming version. Detailed instructions will be provided in the next release's documentation.

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
