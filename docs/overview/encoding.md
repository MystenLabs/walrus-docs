# Encoding, overheads, and verification

We summarize here the basic encoding and cryptographic techniques used in Walrus.

- **Storage nodes** hold one or many **shards** in a storage epoch, out of a larger total (say 1000)
  and each shard contains one blob **sliver** for each blob past PoA. Each shard is assigned to a
  storage node in a storage epoch.
- An [erasure code](https://en.wikipedia.org/wiki/Online_codes) **encode algorithm** takes a blob,
  and encodes it as $K$ symbols, such that any fraction $p$ of symbols can be used to reconstruct
  the blob. Each blob sliver contains a fixed number of such symbols.
- We select $p<1/3$ so that a third of symbols and also slivers may be used to reconstruct the blob
  by the **decode algorithm**. The matrix used to produce the erasure code is fixed and the same
  for all blobs by the Walrus system, and encoders have no discretion about it.
- Storage nodes manage one or more shards, and corresponding slivers of each blob are distributed
  to all the storage shards. As a result, the overhead of the distributed store is ~5x that of
  the blob itself, no matter how many shards we have. The encoding is systematic meaning that some
  storage nodes hold part of the original blob, allowing for fast random access reads.

Each blob is also associated with some metadata including a blob ID to allow verification:

- A blob ID is computed as an authenticator of the set of all shard data and metadata (byte size,
  encoding, blob hash). We hash a sliver representation in each of the shards and add the resulting
  hashes into a Merkle tree. Then the root of the Merkle tree is the blob hash used to derive the
  blob ID that identifies the blob in the system.
- Each storage node may use the blob ID to check if some shard data belongs to a blob using the
  authenticated structure corresponding to the blob hash (Merkle tree). A successful check means
  that the data is indeed as intended by the writer of the blob (who, remember, may be corrupt).
- When any party reconstructs a blob ID from shard slivers, or accepts any blob claiming
  to be a specific blob ID, it must check that it encodes to the correct blob ID. This process
  involves re-coding the blob using the erasure correction code, and re-deriving the blob ID to
  check the blob indeed matches. This prevents a malformed blob (i.e., incorrectly erasure coded)
  from ever being read as a valid blob at any correct recipient.
- A set of slivers equal to the reconstruction threshold belonging to a blob ID that are either
  inconsistent or lead to the reconstruction of a different ID represent an incorrect encoding
  (this can only happen if the user that encoded the blob was malicious and encoded it incorrectly).
  We can extract one symbol per sliver to form an inconsistency proof.
  Storage nodes may delete slivers belonging to inconsistently encoded blobs,
  and upon request return either the inconsistency proof or an inconsistency certificate posted
  on-chain.
