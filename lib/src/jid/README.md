# JID

This package provides a efficient way to work with Jabber (XMPP) IDs. Jabber IDs consist of three main components: the local part, the domain part, and an optional resource part. This package offers a convenient set of methods for creating, parsing, and manipulating Jabber IDs while ensuring proper formatting and escaping.

## Features

- Create new Jabber IDs with specified local, domain, and resource parts.
- Parse a string representation of a Jabber ID into its components.
- Automatically escape the local part when necessary, ensuring valid Jabber IDs.
- Support for converting Jabber IDs to their bare form, omitting the resource part.
- Compare Jabber IDs for equality and calculate hash codes.
- Generate string representations of Jabber IDs with optional unescaping.
