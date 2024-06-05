# Future discussion

In this document, we left out details of the following features:

- Shard transfer and recovery upon storage epoch change. The encoding scheme used has been designed
  to allow this operation to be efficient. A storage node needs to only get data of the same
  magnitude to the missing sliver data to reconstruct them.
- Details of light clients that can be used to sample availability. Individual clients may sample
  the certified blobs from Sui metadata, and sample the availability of some slivers that they
  store. On-chain bounties may be used to retrieve these slivers for missing blobs.
