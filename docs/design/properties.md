# Walrus assurance and security properties

The properties below hold true subject to the assumption that for all storage epochs 2/3 of shards
are operated by storage nodes that faithfully and correctly follow the Walrus protocol.

As described [before](./encoding.md), each blob is encoded into slivers using an erasure code and a
blob ID is cryptographically derived. For a given blob ID there is a **point of availability (PoA)**
and an **availability period**, observable through an event on the Sui chain.

The following properties relate to the PoA:

- After the PoA, for a blob ID, any correct user that performs a read within the availability period
  will eventually terminate and get a value \(V\) which is either the blob contents \(F\) or `None`.
- After the PoA, if two correct users perform a read and get \(V\) and \(V'\), respectively, then
  \(V = V'\).
- A correct user with an appropriate storage resource can always perform store for a blob \(F\) with
  a blob ID and advance the protocol until the PoA.
- A read after the PoA for a blob \(F\) stored by a correct user, will result in \(F\).

Some assurance properties ensure the correct internal processes of Walrus storage nodes.
For the purposes of defining these, an **inconsistency proof** proves that a blob ID was
stored by a user that incorrectly encoded a blob.

- After the PoA and for a blob ID stored by a correct user, a storage node is always able to recover
  the correct slivers for its shards for this blob ID.
- After the PoA, if a correct storage node cannot recover a sliver, it can produce an inconsistency
  proof for the blob ID.
- If a blob ID is stored by a correct user, an inconsistently proof cannot be derived for it.
- A read by a correct user for a blob ID for which an inconsistency proof may exist returns `None`.

Note that there is no delete operation and a blob ID past the PoA will be available for the full
availability period.

```admonish tip title="Rule of thumb"
Before the PoA it is the responsibility of a client to ensure the availability of a blob and its
upload to Walrus. After the PoA it is the responsibility of Walrus as a system to maintain the
availability of the blob as part of its operation for the full availability period remaining.
Emission of the event corresponding to the PoA for a blob ID attests its availability.
```
