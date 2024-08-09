# Objectives and use cases

Walrus supports operations to store and read blobs, and to prove and verify their availability.
It ensures content survives storage nodes suffering Byzantine faults and remains available and
retrievable. It provides APIs to access the stored content over a CLI, SDKs and over web2 HTTP
technologies, and supports content delivery infrastructures like caches and content distribution
networks (CDNs).

Under the hood, storage cost is a small fixed multiple of the size of blobs (around 5x). Advanced
erasure coding keeps the cost low, in contrast to the full replication of data traditional to
blockchains, such as the >100x multiple for data stored in Sui objects. As a result, storage of much
bigger resources (up to several GiB) is possible on Walrus at substantially lower cost than on Sui
or other blockchains. Because encoded blobs are stored on all storage nodes, Walrus also provides
superior robustness than designs with a small amount of replicas storing the full blob.

Walrus uses the Sui chain for coordination and payments. Available storage is represented as Sui
objects that can be acquired, owned, split, merged, and transferred. Storage space can be tied to
a stored blob for a period of time, with the resulting Sui object used to prove
availability on chain in smart contracts, or off chain using light clients.

The [next chapter](./overview.md) discusses the above operations relating to storage,
retrieval, and availability in detail.

In the future, we plan to include in Walrus some minimal governance to allow storage nodes to
change between storage epochs. Walrus is also compatible with periodic payments for continued
storage. We also plan to implement storage attestation based on challenges to get confidence
that blobs are stored or at least available. Walrus also allows light nodes that store small parts
of blobs to get rewards for proving availability and assisting recovery. We will cover these
topics in later documents. We also provide details of the encoding scheme in a separate document.

## Non-objectives

There are a few things that Walrus explicitly is not:

- Walrus does not reimplement a CDN that might be geo-replicated or have less than tens of
  milliseconds of latency. Instead, it ensures that traditional CDNs are usable and compatible with
  Walrus caches.

- Walrus does not re-implement a full smart contracts platform with consensus or execution. It
  relies on Sui smart contracts when necessary, to manage Walrus resources and processes including
  payments, storage epochs, and so on.

- Walrus supports storage of any blob, including encrypted blobs. However, Walrus itself is not the
  distributed key management infrastructure that manages and distributed encryption or decryption
  keys to support a full private storage eco-system. It can, however, provide the storage layer for
  such infrastructures.

## Use cases

App builders may use Walrus in conjunction with any L1 or L2 blockchains to build experiences that
require large amounts of data to be stored in a decentralized manner and possibly certified as
available:

- **Storage of media for NFT or dApps:** Walrus can directly store and serve media such as images,
  sounds, sprites, videos, other game assets, and so on. This is publicly available media that is
  accessed using HTTP requests at caches to create multimedia dApps.

- **AI related use cases:** Walrus can store clean data sets of training data, datasets with a
  known and verified provenance, models, weights and proofs of correct training for AI models.
  It can also store and ensure the availability of an AI model output.

- **Storage of long term archival of blockchain history:** Walrus can act as a lower-cost
  decentralized store to store blockchain history. For Sui, this can include sequences of
  checkpoints with all associated transaction and effects content, as well as historic snapshots
  of the blockchain state, code, or binaries.

- **Support availability for L2s:** Walrus allows parties to certify the availability of blobs, as
  required by L2s that need data to be stored and be attested as available to all. This may also
  include availability of extra audit data such as validity proofs, zero knowledge proofs of
  correct execution or large fraud proofs.

- **Support a fully decentralized web experience:** Walrus can host fully decentralized web
  experiences, including all resources (such as js, css, html, media). These can not only
  provide content, but also host the UX of dApps to enable applications with fully decentralized
  front end and back ends on chain. Walrus puts the full "web" into web3.

- **Support subscription models for media:** Creators can store encrypted media on Walrus and only
  provide access via decryption keys to parties that have paid a subscription fee or have paid for
  content. Walrus provides the storage, encryption and decryption needs to happen off
  the system.
