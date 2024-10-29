# Walrus

Welcome to the developer documentation for Walrus, a decentralized storage and data availability
protocol designed specifically for large binary files, or "blobs". Walrus focuses on providing a
robust but affordable solution for storing unstructured content on decentralized storage nodes
while ensuring high availability and reliability even in the presence of Byzantine faults.

```admonish tip title="Fun fact"
If you are viewing this site at <https://docs.walrus.site>, you are fetching this from
Walrus behind the scenes. See the [Walrus Sites chapter](./walrus-sites/intro.md) for further
details on how this works.
```

```admonish danger title="Disclaimer about the Walrus Testnet"
The current Testnet release of Walrus and Walrus Sites is a preview intended to showcase
the technology and solicit feedback from builders, users, and storage-node operators.
All transactions are executed on the Sui Testnet and use Testnet WAL and SUI which have no
value. The state of the store **can and will be wiped** at any point and possibly with no warning.
Do not rely on this Testnet for any production purposes, it comes with no availability or
persistence guarantees.

Furthermore, encodings and blob IDs may be incompatible with the future Testnet and Mainnet, and
developers will be responsible for migrating any Testnet applications and data to Mainnet. Detailed
migration guides will be provided when Mainnet becomes available.

Also see the [Testnet terms of service](../testnet_tos.md) under which this Testnet is made
available.
```

```admonish danger title="Public access"
**All blobs stored in Walrus are public and discoverable by all.** Therefore you must not use Walrus
to store anything that contains secrets or private data without additional measures to protect
confidentiality.
```

```admonish danger title="Discontinuation of Walrus Devnet"
The previous Walrus Devnet instance is now deprecated and **will be shut down after 2024-10-31**.
All data stored on Walrus Devnet (including Walrus Sites) will no longer be accessible at that
point. You need to re-upload all data to Walrus Testnet if you want it to remain accessible. Walrus
Sites also need to be migrated as described on the dedicated [migration
page](./walrus-sites/tutorial-migration.md).
```

## Features

- **Storage and retrieval:** Walrus supports storage operations to write and read blobs. It also
  allows anyone to prove that a blob has been stored and is available for retrieval at a later
  time.

- **Cost efficiency:** By utilizing advanced erasure coding, Walrus maintains storage costs at
  approximately five times the size of the stored blobs, and encoded parts of each blob are stored
  on each storage node. This is significantly more cost-effective than traditional full-replication
  methods and much more robust against failures than protocols that only store each blob on a subset
  of storage nodes.

- **Integration with the Sui blockchain:** Walrus leverages [Sui](https://github.com/MystenLabs/sui)
  for coordination, attesting availability, and payments. Storage space is represented as a resource
  on Sui, which can be owned, split, merged, and transferred. Stored blobs are also represented by
  objects on Sui, which means that smart contracts can check whether a blob is available and for how
  long, extend its lifetime or optionally delete it.

- **Epochs, tokenomics, and delegated proof of stake** Walrus is operated by a committee of storage
  nodes that evolve between epochs. A native token, WAL (and its subdivision FROST, where 1 WAL is
  equal to 1 billion FROST), is used to delegate stake to storage nodes, and those with high stake
  become part of the epoch committee. The WAL token is also used for payments for storage. At the
  end of each epoch, rewards for selecting storage nodes, storing and serving blobs are distributed
  to storage nodes and whose that stake with them. All these processes are mediated by smart
  contracts on the Sui platform.

- **Flexible access:** Users can interact with Walrus through a command-line interface (CLI),
  software development kits (SDKs), and web2 HTTP technologies. Walrus is designed to work well
  with traditional caches and content distribution networks (CDNs), while ensuring all operations
  can also be run using local tools to maximize decentralization.

## Architecture and operations

Walrus's architecture ensures that content remains accessible and retrievable even when many
storage nodes are unavailable or malicious. Under the hood it uses modern error correction
techniques based on fast linear fountain codes, augmented to ensure resilience against Byzantine
faults, and a dynamically changing set of storage nodes. The core of Walrus remains simple, and
storage node management and blob certification leverages Sui smart contracts.

## Organization

This documentation is split into several parts:

1. *Dev blog* contains announcements and other blog posts.
1. *Design* describes the objectives, security properties, and architecture of Walrus.
1. *Usage* provides concrete information for developers. If you want to get started quickly, you can
   jump directly to the [setup chapter](./usage/setup.md).
1. *Walrus Sites* describes how you can use Walrus and Sui together to build truly decentralized
   websites.

Finally, we provide a [glossary](./glossary.md) that explains the terminology used throughout the
documentation.

## Sources

This documentation is built using [mdBook](https://rust-lang.github.io/mdBook/) from source files in
<https://github.com/MystenLabs/walrus-docs/>. Please report or fix any errors you find in this
documentation in that GitHub project.
