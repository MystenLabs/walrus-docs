# Sui Structures

This section is optional and enables advanced use cases.

You can interact with Walrus purely through the client CLI, and JSON or HTTP APIs provided, without
querying or executing transactions on Sui directly. However, Walrus uses Sui to manage its metadata
and smart contract developers can read information about the Walrus system, as well as stored blobs,
on Sui.

The Move code of the Walrus Devnet contracts is available at
<https://github.com/MystenLabs/walrus-docs/blob/main/contracts/blob_store>. An example package using
the Walrus contracts is available at
<https://github.com/MystenLabs/walrus-docs/blob/main/examples/move>.

The following sections provide further insights into the contract and an overview of how you may use
Walrus objects in your own Sui smart contracts.

```admonish danger title="A word of caution"
Walrus Testnet will use new Move packages with struct layouts and function signatures that may not
be compatible with this package. Move code that builds against this package will need to rewritten.
```

## Blob and storage objects

Walrus blobs are represented as Sui objects of type `Blob`. A blob is first registered, indicating
that the storage nodes should expect slivers from a Blob ID to be stored. Then a blob is certified,
indicating that a sufficient number of slivers have been stored to guarantee the blob's
availability. When a blob is certified, its `certified_epoch` field contains the epoch in which it
was certified.

A `Storage` object is always associated with a `Blob` object, reserving enough space for
a long enough period for the blob's storage. A certified blob is available for the period the
underlying storage resource guarantees storage.

Concretely, `Blob` and `Storage` objects have the following fields, which can be read through the
Sui SDKs:

```move
/// The blob structure represents a blob that has been registered to with some
/// storage, and then may eventually be certified as being available in the
/// system.
public struct Blob has key, store {
    id: UID,
    stored_epoch: u64,
    blob_id: u256,
    size: u64,
    erasure_code_type: u8,
    certified_epoch: option::Option<u64>, // The epoch first certified,
                                          // or None if not certified.
    storage: Storage,
}

/// Reservation for storage for a given period, which is inclusive start,
/// exclusive end.
public struct Storage has key, store {
    id: UID,
    start_epoch: u64,
    end_epoch: u64,
    storage_size: u64,
}
```

All fields of `Blob` and `Storage` objects can be read using the expected functions:

```move
// Blob functions
public fun stored_epoch(b: &Blob): u64;
public fun blob_id(b: &Blob): u256;
public fun size(b: &Blob): u64;
public fun erasure_code_type(b: &Blob): u8;
public fun certified_epoch(b: &Blob): &Option<u64>;
public fun storage(b: &Blob): &Storage;

// Storage functions
public fun start_epoch(self: &Storage): u64;
public fun end_epoch(self: &Storage): u64;
public fun storage_size(self: &Storage): u64;
```

## Events

When a blob is first registered, a `BlobRegistered` event is emitted that informs storage nodes
that they should expect slivers associated with its Blob ID. Eventually when the blob is
certified, a `BlobCertified` is emitted containing information about the blob ID and the epoch
after which the blob will be deleted. Before that epoch the blob is guaranteed to be available.

```move
/// Signals a blob with metadata is registered.
public struct BlobRegistered has copy, drop {
    epoch: u64,
    blob_id: u256,
    size: u64,
    erasure_code_type: u8,
    end_epoch: u64,
}

/// Signals a blob is certified.
public struct BlobCertified has copy, drop {
    epoch: u64,
    blob_id: u256,
    end_epoch: u64,
}
```

The `InvalidBlobID` event is emitted when storage nodes detect an incorrectly encoded blob.
Anyone attempting a read on such a blob is guaranteed to also detect it as invalid.

```move
/// Signals that a BlobID is invalid.
public struct InvalidBlobID has copy, drop {
    epoch: u64, // The epoch in which the blob ID is first registered as invalid
    blob_id: u256,
}
```

## System information

The Walrus system object contains metadata about the available and used storage, as well as the
price of storage per KiB of storage in MIST. The committee
structure within the system object can be used to read the current epoch number, as well as
information about the committee.

```move
const BYTES_PER_UNIT_SIZE: u64 = 1_024;

public struct System<phantom WAL> has key, store {
    id: UID,

    /// The current committee, with the current epoch.
    /// The option is always Some, but need it for swap.
    current_committee: Option<Committee>,

    /// When we first enter the current epoch we SYNC,
    /// and then we are DONE after a cert from a quorum.
    epoch_status: u8,

    // Some accounting
    total_capacity_size: u64,
    used_capacity_size: u64,

    /// The price per unit size of storage.
    price_per_unit_size: u64,

    /// Tables about the future and the past.
    past_committees: Table<u64, Committee>,
    future_accounting: FutureAccountingRingBuffer<WAL>,
}

public struct Committee has store {
    epoch: u64,
    bls_committee: BlsCommittee,
}
```

A few public functions of the committee allow contracts to read Walrus metadata:

```move
/// Get epoch. Uses the committee to get the epoch.
public fun epoch<WAL>(self: &System<WAL>): u64;

/// Accessor for total capacity size.
public fun total_capacity_size<WAL>(self: &System<WAL>): u64;

/// Accessor for used capacity size.
public fun used_capacity_size<WAL>(self: &System<WAL>): u64;

// The number of shards
public fun n_shards<WAL>(self: &System<WAL>): u16;
```
