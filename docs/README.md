# Walrus

Welcome to the developer documentation for Walrus, a decentralized storage and availability protocol
designed specifically for large binary files, or "blobs". Walrus focuses on providing a robust
solution for storing unstructured content on decentralized storage nodes while ensuring high
availability and reliability even in the presence of Byzantine faults.

Fun fact: If you are viewing this site at <https://docs.walrus.site>, you are fetching this from
Walrus behind the scenes. See the [Walrus Sites chapter](./walrus-sites/intro.md) for further
details on how this works.

## Features

- **Storage and retrieval**: Walrus supports storage operations to write and read blobs. It also
  allows anyone to prove that a blob has been stored and is available for retrieval at a later
  time.

- **Cost efficiency**: By utilizing advanced error correction coding, Walrus maintains storage
  costs at approximately five times the size of the stored blobs and encoded parts of each blob
  are stored on each storage node. This is significantly more cost-effective compared to
  traditional full replication methods and much more robust against failures compared to
  protocols that only store each blob on a subset of storage nodes.

- **Integration with Sui blockchain**: Walrus leverages the [Sui](https://github.com/MystenLabs/sui)
  for coordination, attesting availability and payments. Storage space can be owned as a resource on
  Sui, split, merged, and transferred. Blob storage is represented using storage objects on Sui, and
  smart contracts can check whether a blob is available and for how long.

- **Flexible access**: Users can interact with Walrus through a command-line interface (CLI),
  software development kits (SDKs), and web2 HTTP technologies. Walrus is designed to work well
  with traditional caches and content distribution networks (CDNs), while ensuring all operations
  can also be run using local tools to maximize decentralization.

## Architecture and operations

Walrus's architecture ensures that content remains accessible and retrievable even when many
storage nodes are unavailable or malicious. Under the hood it uses modern error correction
techniques based on fast linear fountain codes, augmented to ensure resilience against Byzantine
faults, and a dynamically changing set of storage nodes. The core of Walrus remains simple, and
storage node management and blob certification leverages Sui smart contracts.

This documentation is split into several parts. The first part provides an overview of the
objectives, security properties, and architecture of the Walrus system. The second part contains
concrete documentation on the usage of Walrus. At the end, we provide a [glossary](./glossary.md),
which defines key terms used throughout the project.

Walrus is architected to provide a reliable and cost-effective solution for large-scale blob
storage, making it an ideal choice for applications requiring decentralized, affordable, durable,
and accessible data storage.

## Organization

This documentation is split into three parts:

1. _About Walrus_ describes the design and architecture of Walrus.
1. _Usage_ provides concrete information for developers. If you want to get started quickly, you can
   jump directly to the [setup chapter](./usage/setup.md).
1. _Walrus sites_ describes how you can use Walrus and Sui together to build truly decentralized
   websites.

Finally, we provide a [glossary](./glossary.md) that explains the terminology used throughout the
documentation.

## Sources

This documentation is built using [mdBook](https://rust-lang.github.io/mdBook/) from source files in
[github.com/MystenLabs/walrus-docs/](https://github.com/MystenLabs/walrus-docs/). Please report or
fix any errors you find in this documentation in that GitHub project.
