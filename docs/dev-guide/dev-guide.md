# Developer guide

This guide introduces all the concepts needed to build applications that use Walrus as a storage
or availability layer. The [overview](../design/overview.md) provides more background and explains
in more detail how Walrus operates internally.

This developer guide describes the following:

- [Components](components.md) of Walrus of interest to developers that wish to use it for
  storage or availability.
- [Operations](dev-operations.md) supported through client binaries, APIs, or Sui operations.
- [The Sui structures](sui-struct.md) Walrus uses to store metadata, and how they can be read
  from Sui smart contracts, or through the Sui SDK.

Refer again to the [glossary](../glossary.md) of terms as a reference.

```admonish danger title="Disclaimer about the Walrus developer preview"
The current Devnet release of Walrus and Walrus Sites is a developer preview intended to showcase
the technology and solicit feedback from builders. All storage nodes and aggregators are operated by
Mysten Labs and all transactions are executed on the Sui Testnet and use Testnet SUI which has no
value. The state of the store **can and will be wiped**, at any point and possibly with no warning.
Do not rely on this developer preview for any production purposes, it comes with no availability or
persistence guarantees.

Furthermore, encodings and blob IDs may be incompatible with the future Testnet and Mainnet and
developers will be responsible for migrating any Devnet applications and data to Testnet. Detailed
migration guides will be provided when Testnet becomes available.

Also see the [Devnet terms of service](../tos.md) under which this developer preview is made
available.
```
