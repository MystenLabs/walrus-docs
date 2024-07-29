# Operations on Sui

Walrus uses Sui smart contracts to coordinate storage operations as resources that have a lifetime,
and payments. Smart contracts also facilitate governance to determine the storage nodes holding each
storage shard. The following content outlines these operations and refers to them as part of the
read/write paths.

Metadata is the only blob element ever exposed to Sui or its validators, as the content
of blobs is always stored off chain on Walrus storage nodes and caches. The storage nodes or caches
do not have to overlap with any Sui infrastructure components (such as validators), and the storage
epochs can be of different lengths and not have the same start/end times as Sui epochs.

## Storage resource life cycle on Sui

A number of Sui smart contracts hold the metadata of the Walrus system and all its entities.

- A **Walrus system object** holds the committee of storage nodes for the current storage epoch. The
  system object also holds the total available space on Walrus and the price per unit of storage (1
  KiB).

  These values are determined by 2/3 agreement between the storage nodes for the storage
  epoch. Users can pay to purchase storage space for some time duration. These space resources can
  be split, merged, and transferred. Later, they can be used to place a blob ID into Walrus.

- The **storage fund** holds funds for storing blobs over one or multiple storage epochs. When
  purchasing storage space from the system object, users pay into the storage fund separated over
  multiple storage epochs. Payments are made each epoch to storage nodes according to performance
  (details follow).

- A user acquires some storage through the contracts or transfer and can assign to it a blob ID,
  signifying they want to store this blob ID into it. This emits a Move **resource event** that
  storage nodes listen for to expect and authorize off-chain storage operations.

- Eventually a user holds an off-chain **availability certificate** from storage nodes for a blob
  ID. The user **uploads the certificate on chain** to signal that the blob ID is available for an
  availability period. The certificate is checked against the latest Walrus committee,
  and an **availability event** is emitted for the blob ID if correct. This is the point of
  availability for the blob.

- At a later time, a certified blob's storage can be **extended** by adding a storage object to it
  with a longer expiry period. This facility can be used by smart contracts to extend the
  availability of blobs stored in perpetuity as long as funds exist to continue providing storage.

- In case a blob ID is not correctly encoded, an **inconsistency proof certificate** can be uploaded
  on chain at a later time. This action emits an **inconsistent blob event**, signaling that the
  blob ID read results always return `None`. This indicates that its slivers can be deleted by
  storage nodes, except for an indicator to return `None`.

Users writing to Walrus, need to perform Sui transactions to acquire storage and certify blobs.
Users creating or consuming proofs for attestations of blob availability read the chain
only to prove or verify emission of events. Nodes read
the blockchain to get committee metadata only once per epoch, and then request slivers directly
from storage nodes by blob ID to perform reads on Walrus resources.

## Governance operations on Sui

Each Walrus storage epoch is represented by the Walrus system object that contains a storage
committee and various metadata or storage nodes, like the mapping between shards and storage nodes,
available space, and current costs.

Users can go to the system object for the period and **buy some storage** amount for one or more
storage epochs. At each storage epoch there is a price for storage, and the payment provided becomes
part of a **storage fund** for all the storage epochs that span the storage bought. There is a
maximum number of storage epochs in the future for which storage can be bought (approximately 2
years). Storage is a resource that can be split, merged, and transferred.

At the end of the storage epoch, part of the funds in the **storage fund need to be allocated to
storage nodes**. The idea here is for storage nodes to perform light audits of each other,
and suggest which nodes are to be paid based on the performance of these audits.
