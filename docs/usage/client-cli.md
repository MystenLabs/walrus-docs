# Using the Walrus client

The `walrus` binary can be used to interact with Walrus as a client. See the [setup
chapter](./setup.md) for prerequisites, installation, and configuration.

Detailed usage information is available through

```sh
walrus --help
```

Each sub-command of `walrus` can also be called with `--help` to print its specific arguments and
their meaning.

## Walrus system information

Information about the Walrus system is available through the `walrus info` command. It provides an
overview of current system parameters such as the current epoch, the number of storage nodes and
shards in the system, the maximum blob size, and the current cost in (Testnet) WAL for storing
blobs:

```console
$ walrus info

Walrus system information

Epochs and storage duration
Current epoch: 1
Epoch duration: 2day
Blobs can be stored for at most 365 epochs in the future.

Storage nodes
Number of storage nodes: 30
Number of shards: 1000

Blob size
Maximum blob size: 13.3 GiB (14,273,391,930 B)
Storage unit: 1.00 MiB

Approximate storage prices per epoch
(Conversion rate: 1 WAL = 1,000,000,000 FROST)
Price per encoded storage unit: 100 FROST
Additional price for each write: 2,000 FROST
Price to store metadata: 6,200 FROST
Marginal price per additional 1 MiB (w/o metadata): 500 FROST

Total price for example blob sizes
16.0 MiB unencoded (135 MiB encoded): 13,500 FROST per epoch
512 MiB unencoded (2.33 GiB encoded): 0.0002 WAL per epoch
13.3 GiB unencoded (60.5 GiB encoded): 0.0062 WAL per epoch
```

```admonish tip title="FROST and WAL"
FROST is the smaller unit of WAL, similar to MIST for SUI. The conversion is also the same as for
SUI: `1 WAL = 1 000 000 000 FROST`.
```

Additional information such as encoding parameters and sizes, BFT system information, and
information on the storage nodes in the current and (if already selected) the next committee,
including their node IDs and stake and shard distribution can be viewed with the `--dev` argument:
`walrus info --dev`.

## Storing blobs

```admonish danger title="Public access"
**All blobs stored in Walrus are public and discoverable by all.** Therefore you must not use Walrus
to store anything that contains secrets or private data without additional measures to protect
confidentiality.
```

```admonish warning
It must be ensured that only a single process uses the Sui wallet for write actions (storing or
deleting). When using multiple instances of the client simultaneously, each of them must be pointed
to a different wallet. However, it is possible to store multiple blobs with a single `walrus store`
command.
```

```admonish tip title="Obtaining Testnet WAL"
You can exchange Testnet SUI for Testnet WAL by running `walrus get-wal`. See the [setup
page](./setup.md#testnet-wal-faucet) for further details.
```

Storing one or multiple blobs on Walrus can be achieved through the following command:

```sh
walrus store <FILES> --epochs <EPOCHS>
```

The mandatory CLI argument `--epochs <EPOCHS>` indicates the number of epochs the blob should be
stored for. There is an upper limit on the number of epochs a blob can be stored for, which is 365
for the current Testnet deployment.

You can store a single file or multiple files, separated by spaces. Notably, this is compatible
with glob patterns; for example, `walrus store *.png --epochs <EPOCHS>` will store all PNG files
in the current directory.

By default, the command will store the blob as a *permanent* blob. See the [section on deletable
blobs](#reclaiming-space-via-deletable-blobs) for more details on deletable blobs. Also, by default
an owned `Blob` object is created. It is possible to wrap this into a shared object, which can be
funded and extended by anyone, see the [shared blobs section](#shared-blobs).

```admonish tip title="Automatic optimizations"
When storing a blob, the client performs a number of automatic optimizations, including the
following:

- If the blob is already stored as a *permanent blob* on Walrus for a sufficient number of epochs
  the command does not store it again. This behavior can be overwritten with the `--force`
  CLI option, which stores the blob again and creates a fresh blob object on Sui belonging to the
  wallet address.
- If the user's wallet has a compatible storage resource, this one is (re-)used instead of buying a
  new one.
- If the blob is already certified on Walrus but as a *deletable* blob or not for a sufficient
  number of epochs, the command skips sending data to the storage nodes and just collects the
  availability certificate
```

## Querying blob status

The status of a blob can be queried through one of the following commands:

```sh
walrus blob-status --blob-id <BLOB_ID>
walrus blob-status --file <FILE>
```

This returns whether the blob is stored and its availability period. If you specify a file with the
`--file` option,the CLI re-encodes the content of the file and derives the blob ID before checking
the status.

When the blob is available, the `blob-status` command also returns the `BlobCertified` Sui event ID,
which consists of a transaction ID and a sequence number in the events emitted by the transaction.
The existence of this event certifies the availability of the blob.

## Reading blobs

Reading blobs from Walrus can be achieved through the following command:

```sh
walrus read <some blob ID>
```

By default the blob data is written to the standard output. The `--out <OUT>` CLI option
can be used to specify an output file name. The `--rpc-url <URL>` may be used to specify
a Sui RPC node to use instead of the one set in the wallet configuration or the default one.

## Reclaiming space via deletable blobs

By default `walrus store` uploads a blob and Walrus will keep it available until after its expiry
epoch. Not even the uploader may delete it beforehand. However, optionally, the store command
may be invoked with the `--deletable` flag, to indicate the blob may be deleted before its expiry
by the owner of the Sui blob object representing the blob. Deletable blobs are indicated as such
in the Sui events that certify them, and should not be relied upon for availability by others.

A deletable blob may be deleted with the command:

```sh
walrus delete --blob-id <BLOB_ID>
```

Optionally the delete command can be invoked by specifying a `--file <PATH>` option, to derive the
blob ID from a file, or `--object-id <SUI_ID>` to delete the blob in the Sui blob object specified.

Before deleting a blob, the `walrus delete` command will ask for confirmation unless the `--yes`
option is specified.

The `delete` command reclaims the storage object associated with the deleted blob, which is re-used
to store new blobs. The delete operation provides flexibility around managing storage costs and
re-using storage.

The delete operation has limited utility for privacy: It only deletes slivers from the current epoch
storage nodes, and subsequent epoch storage nodes, if no other user has uploaded a copy of the same
blob. If another copy of the same blob exists in Walrus, the delete operation will not make the blob
unavailable for download, and `walrus read` invocations will download it. After the deletion is
finished, the CLI checks the updated status of the blob to see if it is still accessible in Walrus
(unless the `--no-status-check` option is specified). However, even if it isn't, copies of the
public blob may be cached or downloaded by users, and these copies are not deleted.

```admonish danger title="Delete reclaims space only"
**All blobs stored in Walrus are public and discoverable by all.** The `delete` command will
not delete slivers if other copies of the blob are stored on Walrus possibly by other users.
It does not delete blobs from caches, slivers from past storage nodes, or copies
that could have been made by users before the blob was deleted.
```

## Shared blobs

*Shared blobs* are shared Sui objects wrapping "standard" `Blob` objects that can be funded and
whose lifetime can be extended by anyone. See the [shared blobs
contracts](https://github.com/MystenLabs/walrus-docs/blob/main/contracts/walrus/sources/system/shared_blob.move)
for further details.

You can create a shared blob from an existing `Blob` object you own with the `walrus share` command:

```sh
walrus share --blob-obj-id <BLOB_OBJ_ID>
```

The resulting shared blob can be directly funded by adding an `--amount`, or you can fund an
existing shared blob with the `walrus fund-shared-blob` command.

Additionally, you can immediately share a newly created blob by adding the `--share` option to the
`walrus store` command.

## Blob ID utilities

The `walrus blob-id <FILE>` may be used to derive the blob ID of any file. The blob ID is a
commitment to the file, and any blob with the same ID will decode to the same content. The blob
ID is a 256 bit number and represented on some Sui explorer as a decimal large number. The
command `walrus convert-blob-id <BLOB_ID_DECIMAL>` may be used to convert it to a base64 URL safe
encoding used by the command line tools and other APIs.

The `walrus list-blobs` command lists all the non expired Sui blob object that the current account
owns, including their blob ID, object ID, and metadata about expiry and deletable status.
The option `--include-expired` also lists expired blob objects.

## Changing the default configuration

Use the `--config` option to specify a custom path to the
[configuration location](../usage/setup.md#configuration).

The `--wallet <WALLET>` argument may be used to specify a non-standard Sui wallet configuration
file. And a `--gas-budget <GAS_BUDGET>` argument may be used to change the maximum amount of Sui (in
MIST) that the command is allowed to use.
