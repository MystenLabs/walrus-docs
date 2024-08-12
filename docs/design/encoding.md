# Encoding, overheads, and verification

The following list summarizes the basic encoding and cryptographic techniques used in Walrus:

- An [erasure code](https://en.wikipedia.org/wiki/Erasure_code) encode algorithm takes a blob,
  splits it into a number \(k\) of symbols, and encodes it into \(n>k\) symbols in such a way that a
  subset of these \(n\) symbols can be used to reconstruct the blob.

- Walrus uses a highly efficient erasure code and selects \(k\) such that a third of symbols can be
  used to reconstruct the blob by the decode algorithm.

- The encoding is *systematic*, meaning that some storage nodes hold part of the original blob,
  allowing for fast random-access reads.

- All encoding and decoding operations are deterministic, and encoders have no discretion about it.

- For each blob, multiple symbols are combined into a **sliver**, which is then assigned to a shard.

- Storage nodes manage one or more shards, and corresponding slivers of each blob are distributed
  to all the storage shards.

The detailed encoding setup results in an expansion of the blob size by a factor of \(4.5 \sim 5\).
This is independent of the number of shards and the number of storage nodes.

---

Each blob is also associated with some metadata including a **blob ID** to allow verification:

- The blob ID is computed as an authenticator of the set of all shard data and metadata (byte size,
  encoding, blob hash).

  Walrus hashes a sliver representation in each of the shards and adds the resulting hashes into a
  Merkle tree. Then the root of the Merkle tree is the blob hash used to derive the blob ID that
  identifies the blob in the system.

- Each storage node can use the blob ID to check if some shard data belongs to a blob using the
  authenticated structure corresponding to the blob hash (Merkle tree). A successful check means
  that the data is indeed as intended by the writer of the blob.

- As the writer of a blob might have incorrectly encoded a blob (by mistake or on purpose), any
  party that reconstructs a blob ID from shard slivers must check that it encodes to the correct
  blob ID. The same is necessary when accepting any blob claiming to be a specific blob ID.

  This process involves re-encoding the blob using the erasure code, and deriving the blob ID again
  to check that the blob matches. This prevents a malformed blob (incorrectly erasure coded) from
  ever being read as a valid blob at any correct recipient.

- A set of slivers equal to the reconstruction threshold belonging to a blob ID that are either
  inconsistent or lead to the reconstruction of a different ID represent an incorrect encoding. This
  happens only if the user that encoded the blob was faulty or malicious and encoded it incorrectly.

  Walrus can extract one symbol per sliver to form an inconsistency proof. Storage nodes can delete
  slivers belonging to inconsistently encoded blobs, and upon request return either the
  inconsistency proof or an inconsistency certificate posted on chain.
