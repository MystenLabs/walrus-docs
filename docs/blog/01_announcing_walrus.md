# Announcing Walrus: A Decentralized Storage and Data Availability Protocol

Walrus is an innovative decentralized storage network for blockchain apps and autonomous agents. The
Walrus storage system is being released today as a developer preview for Sui builders in order to
gather feedback. We expect a broad rollout to other web3 communities very soon!

Leveraging innovations in erasure coding, Walrus enables fast and robust encoding of unstructured
data blobs into smaller slivers distributed and stored over a network of storage nodes. A subset of
slivers can be used to rapidly reconstruct the original blob, even when up to two-thirds of the
slivers are missing. This is possible while keeping the replication factor down to a minimal 4x-5x,
similar to existing cloud-based services, but with the additional benefits of decentralization and
resilience to more widespread faults.

## The Replication Challenge

Sui is the most advanced blockchain system in relation to storage on validators, with innovations
such as a [storage fund](https://docs.sui.io/concepts/tokenomics/storage-fund) that future-proofs
the cost of storing data on-chain. Nevertheless, Sui still requires complete data replication among
all validators, resulting in a replication factor of 100x or more in today’s Sui Mainnet. While this
is necessary for replicated computing and smart contracts acting on the state of the blockchain, it
is inefficient for simply storing unstructured data blobs, such as music, video, blockchain history,
etc.

## Introducing Walrus: Efficient and Robust Decentralized Storage

To tackle the challenge of high replication costs, Mysten Labs has developed Walrus, a decentralized
storage network offering exceptional data availability and robustness with a minimal replication
factor of 4x-5x. Walrus provides two key benefits:

1. **Cost-Effective Blob Storage:** Walrus allows for the uploading of gigabytes of data at a time
   with minimal cost, making it an ideal solution for storing large volumes of data. Walrus can do
   this because the data blob is transmitted only once over the network, and storage nodes only
   spend a fraction of resources compared to the blob size. As a result, the more storage nodes the
   system has, the fewer resources each storage node uses per blob.

1. **High Availability and Robustness:** Data stored on Walrus enjoys enhanced reliability and
   availability under fault conditions. Data recovery is still possible even if two-thirds of the
   storage nodes crash or come under adversarial control. Further, availability may be certified
   efficiently without downloading the full blob.

Decentralized storage can take multiple forms in modern ecosystems. For instance, it offers better
guarantees for digital assets traded as NFTs. Unlike current designs that store data off-chain,
decentralized storage ensures users own the actual resource, not just metadata, mitigating risks of
data being taken down or misrepresented.

Additionally, decentralized storage is not only useful for storing data such as pictures or files
with high availability; it can also double as a low-cost data availability layer for rollups. Here,
sequencers can upload transactions on Walrus, and the rollup executor only needs to temporarily
reconstruct them for execution.

We also believe Walrus will accompany existing disaster recovery strategies for millions of
enterprise companies. Not only is Walrus low-cost, it also provides unmatched layers of data
availability, integrity, transparency, and resilience that centralized solutions by design cannot
offer.

Walrus is powered by the Sui Network and scales horizontally to hundreds or thousands of networked
decentralized storage nodes. This should enable Walrus to offer Exabytes of storage at costs
competitive with current centralized offerings, given the higher assurance and decentralization.

## The Future of Walrus

By releasing this developer preview we hope to share some of the design decisions with the
decentralized app developer community and gather feedback on the approach and the APIs for storing,
retrieving, and certifying blobs. In this developer preview, all storage nodes are operated by
Mysten Labs to help us understand use cases, fix bugs, and improve the performance of the software.

Future updates to Walrus will allow for dynamically changing the set of decentralized storage nodes,
as well as changing the mapping of what slivers are managed by each storage node. The available
operations and tools will also be expanded to cover more storage-related use cases. Many of these
functions will be designed with the feedback we gather in mind.

Stay tuned for more updates on how Walrus will revolutionize data storage in the web3 ecosystem.

## What can developers build?

As part of this developer preview, we provide a binary client (currently macOS, ubuntu) that can be
operated from the [command line interface](https://docs.walrus.site/usage/client-cli.html), a [JSON
API](https://docs.walrus.site/usage/json-api.html), and an [HTTP
API](https://docs.walrus.site/usage/web-api.html). We also offer the community an aggregator and
publisher service and a Devnet deployment of 10 storage nodes operated by Mysten Labs.

We hope developers will experiment with building applications that leverage the Walrus Decentralized
Store in a variety of ways. As examples, we hope to see the community build:

- **Storage of media for NFT or dapps:** Walrus can directly store and serve media such as images,
  sounds, sprites, videos, other game assets, etc. This is publicly available media that can be
  accessed using HTTP requests at caches to create multimedia dapps.

- **AI-related use cases:** Walrus can store clean data sets of training data, datasets with a known
  and verified provenance, model weights, and proofs of correct training for AI models. Or it may be
  used to store and ensure the availability and authenticity of an AI model output.

- **Storage of long term archival of blockchain history:** Walrus can be used as a lower-cost
  decentralized store to store blockchain history. For Sui, this can include sequences of
  checkpoints with all associated transaction and effects content, as well as historic snapshots of
  the blockchain state, code, or binaries.

- **Support availability for L2s:** Walrus enables parties to certify the availability of blobs, as
  required by L2s that need data to be stored and attested as available to all. This may also
  include the availability of extra audit data such as validity proofs, zero-knowledge proofs of
  correct execution, or large fraud proofs.

- **Support a full decentralized web experience:** Walrus can host full decentralized web
  experiences including all resources (such as js, css, html, and media). These can provide content
  but also host the UX of dapps, enabling fully decentralized front- and back-ends on chain. It
  brings the full "web" back into "web3".

- **Support subscription models for media:** Creators can store encrypted media on Walrus and only
  provide access via decryption keys to parties that have paid a subscription fee or have paid for
  content. (Note that Walrus provides the storage; encryption and decryption must be done off
  Walrus).

We are excited to see what else the web3 developer community can imagine!

## Getting Started

For this developer preview the public Walrus Devnet is openly available to all developers. Developer
documentation is available at <https://docs.walrus.site>.

SUI Testnet token is the main currency for interacting with Walrus. Developers pay for Walrus Devnet
storage using SUI Testnet tokens which can be acquired at the [Sui Testnet Discord
faucet](https://discord.com/channels/916379725201563759/1037811694564560966).

## One more thing …

The [Walrus Sites website](https://walrus.site), the [Walrus docs](https://docs.walrus.site), and
[this very blog](https://blog.walrus.site) are hosted on Walrus. To learn more about Walrus Sites
and how you can deploy your own, [click here](https://docs.walrus.site/walrus-sites/intro.html).
