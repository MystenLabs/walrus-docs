# Sui Structures

This section is optional and enables advanced use cases.

You can interact with Walrus purely through the client CLI, and JSON or HTTP APIs provided, without
querying or executing transactions on Sui directly. However, Walrus uses Sui to manage its metadata
and smart contract developers can read information about the Walrus system, as well as stored blobs,
on Sui.

The Move code of the Walrus Testnet contracts is available at
<https://github.com/MystenLabs/walrus-docs/blob/main/contracts>. An example package using
the Walrus contracts is available at
<https://github.com/MystenLabs/walrus-docs/blob/main/examples/move>.

The following sections provide further insights into the contract and an overview of how you may use
Walrus objects in your own Sui smart contracts.

```admonish danger title="A word of caution"
Walrus Mainnet will use new Move packages with `struct` layouts and function signatures that may not
be compatible with this package. Move code that builds against this package will need to rewritten.
```

## Blob and storage objects

Walrus blobs are represented as Sui objects of type `Blob`. A blob is first registered, indicating
that the storage nodes should expect slivers from a Blob ID to be stored. Then a blob is certified,
indicating that a sufficient number of slivers have been stored to guarantee the blob's
availability. When a blob is certified, its `certified_epoch` field contains the epoch in which it
was certified.

A `Blob` object is always associated with a `Storage` object, reserving enough space for
a long enough period for the blob's storage. A certified blob is available for the period the
underlying storage resource guarantees storage.

Concretely, `Blob` and `Storage` objects have the following fields, which can be read through the
Sui SDKs:

```move

/// The blob structure represents a blob that has been registered to with some storage,
/// and then may eventually be certified as being available in the system.
public struct Blob has key, store {
    id: UID,
    registered_epoch: u32,
    blob_id: u256,
    size: u64,
    encoding_type: u8,
    // Stores the epoch first certified.
    certified_epoch: option::Option<u32>,
    storage: Storage,
    // Marks if this blob can be deleted.
    deletable: bool,
}

/// Reservation for storage for a given period, which is inclusive start, exclusive end.
public struct Storage has key, store {
    id: UID,
    start_epoch: u32,
    end_epoch: u32,
    storage_size: u64,
}
```

All fields of `Blob` and `Storage` objects can be read using the expected functions:

```move
// Blob functions
public fun blob_id(b: &Blob): u256;
public fun size(b: &Blob): u64;
public fun erasure_code_type(b: &Blob): u8;
public fun registered_epoch(self: &Blob): u32;
public fun certified_epoch(b: &Blob): &Option<u32>;
public fun storage(b: &Blob): &Storage;
...

// Storage functions
public fun start_epoch(self: &Storage): u32;
public fun end_epoch(self: &Storage): u32;
public fun storage_size(self: &Storage): u64;
...
```

## Events

When a blob is first registered, a `BlobRegistered` event is emitted that informs storage nodes
that they should expect slivers associated with its Blob ID. Eventually when the blob is
certified, a `BlobCertified` is emitted containing information about the blob ID and the epoch
after which the blob will be deleted. Before that epoch the blob is guaranteed to be available.

```move
/// Signals that a blob with meta-data has been registered.
public struct BlobRegistered has copy, drop {
    epoch: u32,
    blob_id: u256,
    size: u64,
    encoding_type: u8,
    end_epoch: u32,
    deletable: bool,
    // The object id of the related `Blob` object
    object_id: ID,
}

/// Signals that a blob is certified.
public struct BlobCertified has copy, drop {
    epoch: u32,
    blob_id: u256,
    end_epoch: u32,
    deletable: bool,
    // The object id of the related `Blob` object
    object_id: ID,
    // Marks if this is an extension for explorers, etc.
    is_extension: bool,
}
```

The `BlobCertified` event with `deletable` set to false and a `end_epoch` in the future indicates
that the blob will be available until this epoch. A light client proof this event was emitted
for a blob ID constitutes a proof of availability for the data with this blob ID.

When a deletable blob is deleted, a `BlobDeleted` event is emitted:

```move
/// Signals that a blob has been deleted.
public struct BlobDeleted has copy, drop {
    epoch: u32,
    blob_id: u256,
    end_epoch: u32,
    // The object ID of the related `Blob` object.
    object_id: ID,
    // If the blob object was previously certified.
    was_certified: bool,
}
```

The `InvalidBlobID` event is emitted when storage nodes detect an incorrectly encoded blob.
Anyone attempting a read on such a blob is guaranteed to also detect it as invalid.

```move
/// Signals that a BlobID is invalid.
public struct InvalidBlobID has copy, drop {
    epoch: u32, // The epoch in which the blob ID is first registered as invalid
    blob_id: u256,
}
```

System level events such as `EpochChangeStart` and `EpochChangeDone` indicate transitions
between epochs. And associated events such as `ShardsReceived`, `EpochParametersSelected`,
and `ShardRecoveryStart` indicate storage node level events related to epoch transitions,
shard migrations and epoch parameters.

## System and staking information

The Walrus system object contains metadata about the available and used storage, as well as the
price of storage per KiB of storage in FROST. The committee
structure within the system object can be used to read the current epoch number, as well as
information about the committee.

```move
public struct SystemStateInnerV1 has key, store {
    id: UID,
    /// The current committee, with the current epoch.
    committee: BlsCommittee,
    // Some accounting
    total_capacity_size: u64,
    used_capacity_size: u64,
    /// The price per unit size of storage.
    storage_price_per_unit_size: u64,
    /// The write price per unit size.
    write_price_per_unit_size: u64,
    /// Accounting ring buffer for future epochs.
    future_accounting: FutureAccountingRingBuffer,
    /// Event blob certification state
    event_blob_certification_state: EventBlobCertificationState,
}

/// This represents a BLS signing committee for a given epoch.
public struct BlsCommittee has store, copy, drop {
    /// A vector of committee members
    members: vector<BlsCommitteeMember>,
    /// The total number of shards held by the committee
    n_shards: u16,
    /// The epoch in which the committee is active.
    epoch: u32,
}

public struct BlsCommitteeMember has store, copy, drop {
    public_key: Element<G1>,
    weight: u16,
    node_id: ID,
}

```

<!-- TODO (#146): say more about staking contracts. -->
