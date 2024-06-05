# Off-chain operations

Walrus operations happen off Sui, but may interact with the Sui flows defining the resource life
cycle.

## Write paths

![Write paths of Walrus](assets/WriteFlow.png)

Systems overview of writes, illustrated above:

- A user acquires a storage resource of appropriate size and duration on-chain, either by directly
  buying it on the Walrus system object, or a secondary market. A user can split, merge, and
  transfer storage acquired storage resources.
- When a user wants to write a blob, it first erasure codes it using encode, and computes its
  blob ID. Then they can perform the following steps itself, or use a publisher to perform steps
  on their behalf.
- The user goes on chain (Sui) and updates a storage resource to register the blob ID with the
  appropriate size and lifetime desired. This emits an event, received by storage nodes. Once the
  user receives it then continues the upload.
- The user sends each of the blob slivers and metadata to the storage nodes that currently
  manages the corresponding shards.
- A storage node managing a shard receives a sliver and checks it against the blob ID of the overall
  blob. It also checks that there is a blob resource with that blob ID that is authorized to store
  a blob. If correct, then it signs a statement that it holds the sliver for blob ID (and metadata)
  and returns it to the user.
- The user puts together the signatures returned from storage nodes into an availability certificate
  and sends it on chain. When successfully checked an availability event for the blob ID is emitted,
  and all other storage nodes seek to download any missing shards for the blob ID. This event being
  emitted on Sui is the Point of Availability (PoA) for the blob ID.
- After the PoA, and without user involvement, storage nodes sync and recover any missing slivers
  that are certified.

The user waits for 2/3 of shards signatures to return a certificate of availability. The rate of the
code is below 1/3 allowing for reconstruction if even 1/3 of shards only return the sliver. Since at
most 1/3 of the storage nodes can fail, this ensures reconstruction if a reader requests slivers
from all storage nodes that have signed the ID of the blob. Note that the full process can be
mediated by a publisher, that receives a blob and drives the process to completion.

## Refresh availability

Since no content data is required to refresh the period of storage, refresh is conducted fully on
chain within the protocol. To request an extension to the availability period of a blob, a user
provides an appropriate storage resource. Upon success this emits an event that storage nodes
receive to extend the period each sliver is stored for.

## Inconsistent resource flow

When a correct storage node tries to reconstruct a shard it may fail if the encoding of a blob ID
past PoA was incorrect, and will be able to extract an inconsistency proof for the blob ID. It then
generates a inconsistency certificate and uploads it on chain. The flow is as follows:

- A storage node fails to reconstruct a shard, and generates an inconsistency proof.
- The storage node sends the blob ID and inconsistency proof to all storage nodes of the storage
  epoch, and gets a signature, that it aggregates to an inconsistency certificate.
- The storage node sends the inconsistency certificate to the Walrus smart contract, that checks it
  and emits a inconsistent resource event.
- Upon receiving a inconsistent resource event correct storage nodes delete sliver data and only
  keep a metadata record to return None for the blob ID for the availability period. No storage
  attestation challenges are issued for this blob ID.

Note that a blob ID that is inconsistent will always resolve to None upon reading: this is due to
the read process running the decoding algorithm, and then re-encoding to check the blob ID is
correctly derived from a consistent encoding. This means that an inconsistency proof only reveals a
true fact to storage nodes (that may not otherwise have ran decoding), and does not change the
output of read in any case.

Note however that partial reads leveraging the systematic nature of the encoding may return partial
reads for inconsistently encoded files. Thus if consistency and availability of reads is important
dapps should do full reads rather than partial reads.

## Read paths

A user can read stored blobs either directly or through a cache. We discuss here the direct user
journey since this is also the operation of the cache in case of a cache miss. We assume that most
reads will happen through caches, for blobs that are hot, and will not result in requests to
storage nodes.

- The reader gets the metadata for the blob ID from any storage node, and authenticates it using
  the blob ID.
- The reader then sends a request for the shards corresponding to blob ID to storage nodes, and
  waits for f+1 to respond. Sufficient requests are sent in parallel to ensure low latency for
  reads.
- The reader authenticates the slivers returned with the blob ID, reconstructs the blob, and decides
  whether the contents are a valid blob or inconsistent.
- Optionally, for a cache, the result is cached and can be served without re-construction for some
  time, until it is removed from the cache. Requests for the blob to the cache return the blob
  contents, or a proof the blob is inconsistently encoded.

## Challenge mechanism for storage attestation

During an epoch a correct storage node challenges all shards to provide blob slivers past PoA:

- The list of available blobs for the period is determined by the sequence of Sui events up
  to the past period. Inconsistent blobs are not challenged, and a record proving this status
  can be returned instead.
- A challenge sequence is determined by providing a seed to the challenged shard. The sequence is
  then computed based both on the seed AND the content of each challenged blob ID. This creates a
  sequential read dependency.
- The response to the challenge provides the sequence of shard contents for the blob IDs in a
  timely manner.
- The challenger node uses thresholds to determine whether the challenge was passed, and reports
  the result on chain.
- The challenge / response communication is authenticated.

Challenges provide some reassurance that the storage node actually can recover shard data in a
probabilistic manner, avoiding storage nodes getting payment without any evidence they may retrieve
shard data. The sequential nature of the challenge and some reasonable timeout also ensure that
the process is timely.
