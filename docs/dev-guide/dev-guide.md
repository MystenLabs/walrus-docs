# Developer Guide

This guide introduces all the concepts needed to build applications that use Walrus as a storage
or availability layer. The [overview](./overview.md) provides more background and explains in
more detail how Walrus operates internally.

This developer guide describes:

- [Components](components.md) of Walrus of interest to developers that wish to use it for
  storage or availability.
- [Operations](dev-operations.md) supported through client binaries, APIs, or Sui operations.
- [The Sui structures](sui-struct.md) Walrus uses to store metadata, and how they can be read
  from Sui smart contracts, or through the Sui SDK.

## Disclaimer about the Walrus developer preview

**This release of Walrus \& Walrus Sites is a
developer preview, to showcase the technology and solicit feedback from builders. All storage nodes
and aggregators are operated by Mysten Labs, all transactions are executed on the Sui testnet,
and use testnet SUI which has no value. The state of the store can be, and will be wiped, at any
point and possibly with no warning. Do not rely on this developer preview for any production
purposes, it comes with no availability or persistence guarantees.**
