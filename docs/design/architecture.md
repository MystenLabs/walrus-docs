# Basic architecture and security assumptions

The key actors in the Walrus architecture are the following:

- **Users** through **clients** want to store and read **blobs** identified by their **blob ID**.

  These actors are ready to pay for service
  when it comes to writes and non-best-effort reads. Users also want to prove
  the **availability** of a blob to third parties without the cost of sending or receiving the full
  blob.

  Users might be malicious in various ways: they might not want to pay for services, prove the
  availability of unavailable blobs, modify/delete blobs without authorization, try to
  exhaust resources of storage nodes, and so on.

- **Storage nodes** hold one or many **shards** within a **storage epoch**.

  Each blob is erasure into encoded in many **slivers**. Slivers from each stored blob become part
  of all shards. A shard at any storage epoch is associated with a storage node that actually stores
  all slivers of the shard and is ready to serve them.

  A Sui smart contract controls the assignment of shards to storage nodes within
  **storage epochs**, and Walrus assumes that more than 2/3 of the
  shards are managed by correct storage nodes within each storage epoch. This means that Walrus must
  tolerate up to 1/3 of the shards managed by Byzantine storage nodes (approximately 1/3 of the
  storage nodes being Byzantine) within each storage epoch and across storage epochs.

- All clients and storage nodes operate a blockchain client (specifically on Sui), and mediate
  payments, resources (space), mapping of shards to storage nodes ,and metadata through blockchain
  smart contracts. Users interact with the blockchain to acquire storage resources and upload
  certificates for stored blobs. Storage nodes listen to the blockchain events to coordinate
  their operations.

Walrus supports any additional number of optional infrastructure actors that can operate in a
permissionless way:

- **Aggregators** are clients that reconstruct blobs from slivers and make them available to users
  over traditional web2 technologies (such as HTTP). They are optional in that end users may
  reconstruct blobs directly or run a local aggregator to perform Walrus reads over web2
  technologies locally.

- **Caches** are aggregators with additional caching functionality to decrease latency and reduce
  load on storage nodes. Such cache infrastructures may also act as CDNs, split the cost of blob
  reconstruction over many requests, be better connected, and so on. A client can always verify that
  reads from such infrastructures are correct.

- **Publishers** are clients that help end users store a blob using web2 technologies,
  using less bandwidth and custom logic.

  In effect, they receive the blob to be published over traditional web2 protocols (like HTTP) and
  run the Walrus store protocol on the end user's behalf. This includes encoding the blob into
  slivers, distributing the slivers to storage nodes, collecting storage-node signatures and
  aggregating them into a certificate, as well as all other on-chain actions.

  They are optional in that a user can directly interact with Sui and
  the storage nodes to store blobs. An end user can always verify that a publisher
  performed their duties correctly by checking that an event associated with the
  **[point of availability](./properties.md)** for the blob exists on chain
  and then either performing a read to see if Walrus returns the blob or encoding the blob
  and comparing the result to the blob ID in the certificate.

Aggregators, publishers, and end users are not considered trusted components of the system, and they
might deviate from the protocol arbitrarily. However, some of the security properties of Walrus only
hold for honest end users that use honest intermediaries (caches and publishers). Walrus provides a
means for end users to audit the correct operation of both caches and publishers.
