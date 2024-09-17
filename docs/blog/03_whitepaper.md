# Announcing the Official Walrus Whitepaper

In June, Mysten Labs announced Walrus, a new decentralized secure blob store design, and introduced
a developer preview that currently stores over [12TiB](https://capacity.walrus.site/) of data.
[Breaking the Ice](https://info.breakingtheice.sui.io/) gathered over 200 developers to build apps
leveraging decentralized storage.

It is time to unveil the next stage of the project: Walrus will become an independent decentralized
network with its own utility token, WAL, that will play a key role in the operation and governance
of the network. Walrus will be operated by storage nodes through a delegated proof-of-stake
mechanism using the WAL token. An independent Walrus foundation will encourage the advancement and
adoption of Walrus, and support its community of users and developers.

Today, we published the Walrus [whitepaper](../walrus.pdf) (also on
[GitHub](https://github.com/MystenLabs/walrus-docs/blob/main/docs/walrus.pdf)) that offers
additional details, including:

- The encoding scheme and Read / Write operations Walrus uses to ensure both security and efficient
  scaling to 100s and 1000s of storage nodes, including interactions with the Sui blockchain which
  serves as a coordination layer for Walrus’ operations.
- The reconfiguration of storage nodes across epochs, and how the protocol ensures available blobs
  on Walrus remain available over long periods of time.
- The tokenomics of Walrus based on the WAL token, including how staking and staking rewards are
  structured, how pricing and payments for storage are handled and distributed in each epoch, and
  the governance of key system parameters.
- Forward-looking design options, such as a cheap mechanism to challenge and audit storage nodes,
  options for ensuring reads with a higher service quality, possibly against a payment, and designs
  that empower light nodes to meaningfully contribute to the protocol’s robustness, serve reads, and
  be rewarded.

The whitepaper focuses on the steady-state design aspects of Walrus. Further details about the
project, such as timelines, opportunities for community participation, how to join the network as a
storage node, and plans around light nodes, will be shared in subsequent posts.

To be part of this journey:

- Follow us on [Twitter](https://x.com/WalrusProtocol)
- Join our [Discord](https://discord.com/invite/walrusprotocol)
- [Build apps](../README.md) on Walrus
- [Publish a Walrus Site](../walrus-sites/intro.md) and share it
