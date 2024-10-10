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

Information about the Walrus system is available through the `walrus info` command. For example,
<!-- (TODO - update with final) -->

```console
$ walrus info

Walrus system information
Current epoch: 54

Storage nodes
Number of nodes: 10
Number of shards: 1000

Blob size
Maximum blob size: 13.3 GiB (14,273,391,930 B)
Storage unit: 1.00 KiB

Approximate storage prices per epoch
Price per encoded storage unit: 5 FROST
Price to store metadata: 0.0003 WAL
Marginal price per additional 1 MiB (w/o metadata): 24,195 FROST

Total price for example blob sizes
16.0 MiB unencoded (135 MiB encoded): 0.0007 WAL per epoch
512 MiB unencoded (2.33 GiB encoded): 0.012 WAL per epoch
13.3 GiB unencoded (60.5 GiB encoded): 0.317 WAL per epoch

```

gives an overview of the number of storage nodes and shards in the system, the maximum blob size,
and the current cost in (Testnet) WAL for storing blobs. (Note: 1 WAL = 1 000 000 000 FROST)

Additional information such as encoding parameters and sizes, BFT system information, and
information on the storage nodes and their shard distribution can be viewed with the `--dev`
argument: `walrus info --dev`.

## Storing, querying status, and reading blobs

```admonish danger title="Public access"
**All blobs stored in Walrus are public and discoverable by all.** Therefore you must not use Walrus
to store anything that contains secrets or private data without additional measures to protect
confidentiality.
```

Storing blobs on Walrus can be achieved through the following command:

```sh
walrus store <some file>
```

The store command takes a CLI argument `--epochs <EPOCHS>` (or `-e`) indicating the number of
epochs the blob should be stored for. This defaults to 1 epoch, namely the current one.

If the blob is already stored on Walrus for a sufficient number of epochs the command does not store
it again. However, this behavior can be overwritten with the `--force` (or `-f`) CLI option, which
stores the blob again and creates a fresh blob object on Sui belonging to the wallet address.

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

Reading blobs from Walrus can be achieved through the following command:

```sh
walrus read <some blob ID>
```

By default the blob data is written to the standard output. The `--out <OUT>` CLI option (or `-o`)
can be used to specify an output file name. The `--rpc-url <URL>` (or `-r`) may be used to specify
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

The `delete` command reclaims the storage object associated with the deleted blob, which is
re-used to store new blobs. The delete operation provides
flexibility around managing storage costs and re-using storage.

The delete operation has limited utility for privacy: It only deletes slivers from the current
epoch storage nodes, and subsequent epoch storage nodes, if no other user has uploaded a copy of
the same blob. If another copy of the same blob exists in Walrus the delete operation will not
make the blob unavailable for download, and `walrus read` invocations will download it. Copies of
the public blob may be cached or downloaded by users, and these copies are not deleted.

```admonish danger title="Delete reclaims space only"
**All blobs stored in Walrus are public and discoverable by all.** The `delete` command will
not delete slivers if other copies of the blob are stored on Walrus possibly by other users.
It does not delete blobs from caches, slivers from past storage nodes, or copies
that could have been made by users before the blob was deleted.
```

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
