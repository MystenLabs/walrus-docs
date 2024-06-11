# Operations

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