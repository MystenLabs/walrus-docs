# Basic architecture and security assumptions

The key actors in the Walrus architecture are the following:

- **Users** through **clients** want to store and read **blobs**. They are ready to pay for service
  when it comes to writes, and when it comes to non-best-effort reads. Users also want to prove
  the **availability** of a blob to third parties without the cost of sending or receiving the full
  blob. Users may be malicious in various ways: they may wish to not pay for services, prove the
  availability of an unavailable blobs, or modify / delete blobs without authorization, try to
  exhaust resources of storage nodes, etc.
- **Storage nodes** hold one or many **shards** within a **storage epoch**. Each blob is erasure
  encoded in many **slivers** and slivers from each stored blob become part of all shards. A shard
  at any storage epoch is associated with a **storage node** that actually stores all slivers of
  the shard, and is ready to serve them. The assignment of storage nodes to shards within
  **storage epochs** is controlled by a Sui smart contract and we assume that more than 2/3 of the
  shards are managed by correct storage nodes within each storage epoch. This means that we must
  tolerate up to 1/3 Byzantine storage nodes within each storage epoch and across storage epochs.
- All clients and storage nodes operate a **blockchain** client (specifically on Sui), and mediate
  payments, resources (space), mapping of shards to storage nodes, and metadata through blockchain
  smart contracts. Users interact with the blockchain to get storage resources and certify stored
  blobs, and storage nodes listen to the blockchain events to coordinate their operations.

Walrus supports any additional number of optional infrastructure actors that can operate in a
permissionless way:

- **Caches** are **clients** that store one or more full blobs and make them available to users
  over traditional web2 (HTTP, etc) technologies. They are optional in that end-users may also
  operate a local cache, and perform Walrus reads over web2 technologies locally. However, cache
  infrastructures may also act as CDNs, share the cost of blob reconstruction over many requests,
  have better connectivity, etc. A client can always verify that reads from such infrastructures
  are correct.
- **Publishers** are **clients** that help end-users store a blob using web2 technologies, and
  using less bandwidth and custom logic. They in effect receive the blob to be published. over
  traditional web2 protocols (e.g., HTTP), and perform the Walrus store protocol on their behalf,
  including the encoding, distribution of slivers to shards, creation of certificate of certificate,
  and other on-chain actions. They are optional in that a user may directly interact with both Sui
  and storage nodes to store blobs directly. An end user can always verify that a publisher
  performed their duties correctly by attesting availability.

Caches, publishers, and end-users are not considered trusted components of the system, and they may
deviate from the protocol arbitrarily. However, some of the security properties of Walrus only hold
for honest end-users that use honest intermediaries (caches and publishers). We provide means for
end-users to audit the correct operation of both caches and publishers.
