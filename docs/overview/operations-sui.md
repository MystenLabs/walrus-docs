# Operations on Sui

Walrus uses Sui smart contracts to coordinate storage operations as resources that have a lifetime,
and payments. As well as to facilitate governance to determine the storage nodes holding each
storage shard. We outline here these operations and refer to them below as part of the read / write
paths. As a reminder, only blob metadata is ever exposed to Sui or its validators, and the content
of blobs is always stored off-chain on Walrus storage nodes and caches. The storage nodes or caches
do not have to overlap with any Sui infra (validators etc), and the storage epochs may be of
different lengths and not have the same start / end times as Sui epochs.

## Storage resource life cycle on Sui

A number of Sui smart contracts hold the metadata of the Walrus system and all its entities.

- A **Walrus system object** holds the committee of storage nodes for the current storage epoch. The
  system object also holds the total available space on Walrus and the price per unit of storage (1
  KiB). These values are determined by 2/3 agreement between the storage nodes for the storage
  epoch. Users can pay to purchase storage space for some time duration. These space resources may
  be split, merged and transferred. Later they can be used to place a blob ID into Walrus.
- The **storage fund** holds funds for storing blobs over one, multiple storage epochs or
  perpetually. When purchasing storage space from the system object users pay into the storage fund
  separated over multiple storage epochs, and payments are made each epoch to storage nodes
  according to performance (see below).
- A user acquires some storage through the contracts or transfer, and can assign to it a blob ID,
  signifying they wish to store this blob ID into it. This emits a Move **resource event** that
  both caches and storage nodes listen to to expect and authorize off-chain storage operations.
- Eventually a user holds an off-chain **availability certificate** from storage nodes for a blob
  ID. The user **uploads the certificate on chain** to signal that the blob ID is available for an
  availability period. The certificate is checked against the latest Walrus committee,
  and an **availability event** is emitted for the blob ID if correct. This is the PoA for the
  blob.
- At a later time a certified blob's storage may be **extended** by adding a storage object to it
  with a longer expiry period. This facility may be used by smart contracts to extend the
  availability of blobs stored in perpetuity as long as funds exist to continue providing storage.
- In case a blob ID is not correctly encoded a **inconsistency proof certificate** may be uploaded
  on chain at a later time, and an **inconsistent blob event** is emitted signaling to all that the
  blob ID read results will always return None. This indicates that its slivers may be deleted by
  storage nodes, except for an indicator to return None.

Users writing to Walrus, need to perform Sui transactions to acquire storage and certify blobs.
Users creating or consuming proofs for attestations of blob availability read the chain
only to prove or verify emission of events. A node that reads Walrus resources only needs to read
the blockchain to get committee metadata once per epoch, and then they request slivers directly
from storage nodes by blob ID to perform reads.

## Governance operations on Sui

Each Walrus storage epoch is represented by the Walrus system object that contains a storage
committee and various metadata or storage nodes like the mapping between shards and storage nodes,
available space and current costs. User may go to the system object for the period and **buy some
storage** amount for one or more storage epochs. At each storage epoch there is a price for storage,
and the payment provided becomes part of a **storage fund** for all the storage epochs that span
the storage bought. There is a maximum number of storage epochs in the future for which storage can
be bought (~2 years). Storage is a resource that can be split, merged, and transferred.

At the end of the storage epoch part of the funds in the **storage fund need to be allocated to
storage nodes**. The idea here is for storage nodes to perform light audits of each others,
and suggest which nodes are to be paid based on the performance of these audits.
