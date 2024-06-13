# Using the Walrus client

The `walrus` binary can be used to interact with Walrus as a client. See the [setup
chapter](./setup.md) for prerequisites, installation, and configuration.

Detailed usage information is available through

```sh
walrus --help
```

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

## Storing and reading blobs

Storing and reading blobs from Walrus can be achieved through the following commands:

```sh
walrus store <some file>
walrus read <some blob ID>
```

## Changing the default configuration

Use the `--config` option to specify a custom path to the
[configuration location](../usage/configuration.html#configuration-file).

## Troubleshooting

If you get an error like "the specified Walrus system object does not exist", make sure your wallet
is set up for Sui **testnet** and you use the latest [configuration](./setup.md#configuration).
