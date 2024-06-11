# Developer Guide

This guide introduces all the concepts needed to build applications that use Walrus as a storage
or availability layer. The [overview](./overview.md) provides more background and explains in
more detail how Walrus operates internally.

**Disclaimer about the Walrus developer preview: This release of Walrus \& Walrus Sites is a
developer preview, to showcase the technology and solicit feedback from builders. All storage nodes
and aggregators are operated by MystenLabs, all transactions are executed on the Sui testnet,
and use testnet SUI which has no value. The state of the store can be, and will be wiped, at any
point and possibly with no warning. Do not rely on this the developer preview for any production
purposes, it comes with no availability or persistence guarantees.**

## Components

From a developer perspective Walrus has some components that are objects and smart contracts on
Sui, and some components that are an independent set of services. As a rule Sui is used to manage
blob and storage node metadata, while off-sui components are used to actually store and read blob
data, which can be large.

Walrus defines a number of objects and smart contracts on Sui:

- A shared *system object*, records and manages the current committee of storage nodes.
- *Storage resources*, represent empty storage space that may be used to store blobs.
- *Blob resources*, represent blobs being registered and certified as stored.

The system object ID for Walrus can be found in the Walrus `client_config.yaml` file. You may use
any Sui explorer to look at its content, as well as explore the content of blob objects.

Walrus is also composed of a number of services and binaries:

- A client (binary) can be executed locally and provides a
  [Command Line Interface (CLI)](client-cli.html), a [JSON API](json-api.md)
  and an [HTTP API](web-api.md) to perform Walrus operations.
- Aggregators are services that allow download of blobs via HTTP requests.
- Publishers are services used to upload blobs to Walrus.
- A set of storage nodes store encoded stored blobs.

Aggregators, Publishers and other services use the client APIs to interact with Walrus. End-users
of services using walrus interact with the store via custom services, aggregators or publishers that
expose HTTP APIs to avoid the need to run locally a binary client.

## Operations

### Store

Walrus may be used to **store a blob**, via the native client APIs or a publisher. Under the hood a
number of operations happen both on Sui as well as on storage nodes:

- The client or publisher encodes the blob and derives a *blob ID* that identifies the blob. This
  us a `u256` number often encoded as a URL safe base64 string.
- A transaction is executed on Sui to purchase some storage from the system object, and then to
  *register the blob ID* with this storage. Client APIs return the *Sui blob object ID*. The
  transactions use SUI to purchase storage and pay for gas.
- Encoded slivers of the blob are distributed to all storage nodes. They each sign a receipt.
- The signed receipts are aggregated and submitted to the Sui blob object to *certify the blob*.
  Certifying a blob emits a Sui event with the blob ID and the period of availability.

A blob can be considered as available on Walrus once the corresponding Sui blob object has been
certified in the final step. The steps involved in a store can be executed by the binary client,
or a publisher that accepts and publishes blobs via HTTP.

Walrus currently allows the storage of up to XXXX bytes using the client, and YYY bytes using the
aggregator. You may store larger blobs by splitting them into smaller chunks. TODO sizes.

### Read

Walrus can then be used to **read a blob** by providing its blob ID. A read is executed by
performing the following steps:

- The system object on Sui is read to determine the Walrus storage node committee.
- A number of storage nodes are queried for the slivers they store.
- The blob is reconstructed and checked against the blob ID from the recovered slivers.

The steps involved in the read operation are performed by the binary client, or the aggregator
service that exposes an HTTP interface to read blobs.

### Certify Availability

One may *certify the availability of a blob* using Sui. This may be done in 3 different ways:

- A Sui [light-client](https://github.com/MystenLabs/sui/tree/main/crates/sui-light-client) may be
  used to authenticate the certified blob event emitted when the blob ID was certified on Sui.
- A Sui [light-client](https://github.com/MystenLabs/sui/tree/main/crates/sui-light-client) may be
  used to authenticate the blob Sui object corresponding to the blob ID is certified.
- A Sui smart contract can be provided with the blob object on Sui (or a reference to it) to check
  is is certified.

The underlying protocol of the Sui light client returns digitally signed evidence for emitted events
or objects, and can be used by off-line or non-interactive applications as a proof of availability
for the blob ID for a certain number of epochs.

Once a blob is certified, the Walrus store will ensure that sufficient slivers will always be
available on storage nodes to be able to recover it within the specified epochs.

## Sui Structures Reference

Walrus blobs are represented as Sui `Blob` types. A blob may be registered, indicating that the
storage nodes should expect slivers from a Blob ID to be stored. Then a blob can be certified
indicating that a sufficient number of slivers have been stored to guarantee the blob's
availability. When a blob is certified its `certified` filed contains the epoch in which it was
certified.

A `Storage` object is always associated with a Blob, reserving enough space for
a long enough period for its storage. A certified blob is available for the period the
underlying storage resource guarantees storage.

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
        certified: option::Option<u64>, // The epoch first certified,
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

When a blob is first registered a `BlobRegistered` event is emitted that informs storage nodes
that they should expect slivers associated with its Blob ID. Eventually when the blob is
certified a `BlobCertified` is emitted containing information about the blob ID and the epoch
after which the blob will be deleted. Before that epoch the blob is guaranteed to be available.


```move
    /// Signals a blob with meta-data is registered.
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

    /// Signals that a BlobID is invalid.
    public struct InvalidBlobID has copy, drop {
        epoch: u64, // The epoch in which the blob ID is first registered as invalid
        blob_id: u256,
    }
```

The Walrus system object contains meta-data about the available and used storage, as well as the
price of storage per 100 Kib of storage in MIST. The committee
structure within the system object can be used to read the current epoch number, as well as
information about the committee.

```move
    public struct System<phantom WAL> has key, store {

        id: UID,

        /// The current committee, with the current epoch.
        /// The option is always Some, but need it for swap.
        current_committee: Option<Committee>,

        /// When we first enter the current epoch we SYNC,
        /// and then we are DONE after a cert from a quorum.
        epoch_status: u8,

        // Some accounting
        total_capacity_size : u64,
        used_capacity_size : u64,

        /// The price per unit size of storage.
        price_per_unit_size: u64,

        /// Tables about the future and the past.
        past_committees: Table<u64, Committee>,
        future_accounting: FutureAccountingRingBuffer<WAL>,
    }

    public struct Committee has store {
        epoch: u64,
        bls_committee : BlsCommittee,
    }


```

## Walrus Sites

Walrus Sites is a service that uses Walrus to store websites and serve them to web clients.

TODO