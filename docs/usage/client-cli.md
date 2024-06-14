# Using the Walrus client

The `walrus` binary can be used to interact with Walrus as a client. See the [setup
chapter](./setup.md) for prerequisites, installation, and configuration.

Detailed usage information is available through

```sh
walrus --help
```

Each sub-command of `walrus` can also be called with `--help` (or `-h`) to print its specific
arguments and their meaning.

## Walrus system information

Information about the Walrus system is available through the `walrus info` command. For example,

```console
$ walrus info

Walrus system information

Storage nodes
Number of nodes: 10
Number of shards: 270

Blob size
Maximum blob size: 957 MiB (1,003,471,920 B)

Approximate storage prices per epoch
Price per encoded storage unit: 50 MIST/KiB
Price to store metadata: 850 MIST
Marginal price per additional 1 MiB (w/o metadata): 239,250 MIST
Total price per max blob (957 MiB): 0.227 SUI
```

gives an overview of the number of storage nodes and shards in the system, the maximum blob size,
and the current cost in (testnet) Sui for storing blobs.

Additional information such as encoding parameters and sizes, BFT system information, and
information on the storage nodes and their shard distribution can be viewed with the `--dev`
argument: `walrus info --dev`.

## Storing, querying status and reading blobs

Storing blobs on Walrus can be achieved through the following commands:

```sh
walrus store <some file>
```

The store command takes an CLI argument `--epochs <EPOCHS>` (or `-e`) indicating the number of
epochs the blob should be stored for. This defaults to 1 epoch, namely the current one. If the blob
is already stored on Walrus for a sufficient number of epochs the command does not store it again.

However, this behavior can be overwritten with the `--force` (or `-f`) CLI option, which stores
the blob again and creates a fresh blob object on Sui belonging to the wallet address. Note that
when a blob already exists and is re-uploaded there is hardly any networking cost, since slivers
on storage nodes are re-used.

The status of a blob by blob ID can be queried using the command:

```sh
walrus blob-status --blob-id <BLOB_ID>
```

This returns whether the blob is stored and its availability period. You can also query the
status of a blob by using a file that stores it, as:

```sh
walrus blob-status --file <FILE>
```

This command re-encodes the content of the file, derives the blob ID and returns whether it
is stored on Walrus and its availability period.

When the blob is available the `blob-status` command also returns the `BlobCertified` Sui event ID,
which consists of a transaction ID and a sequence number in the events emitted by the transaction.
The existence of this event certifies the availability of the blob.

Reading blobs from Walrus can be achieved through the following command:

```sh
walrus read <some blob ID>
```

By default the content of the file are sent to standard out. The `--out <OUT>` CLI option (or `-o`)
can be used to specify and output file name. The `--rpc-url <URL>` (or `-r`) may be used to specify
an aggregator address to use instead of the standard one.

## Changing the default configuration

Use the `--config` option to specify a custom path to the
[configuration location](../usage/configuration.html#configuration-file).

The
`--wallet <WALLET>` argument may be used to specify a non standard Sui wallet configuration file.
And a `--gas-budget <GAS_BUDGET>` argument may be used to change the maximum amount of Sui (in MIST)
that the command is allowed to use.

## Troubleshooting

If you get an error like "the specified Walrus system object does not exist", make sure your wallet
is set up for Sui **testnet** and you use the latest [configuration](./configuration.md).
