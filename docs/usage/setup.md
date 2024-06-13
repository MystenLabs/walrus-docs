# Setup

At this stage of the project, our Walrus code is not yet public. Instead, we provide a pre-compiled
`walrus` client binary for macOS (Intel and Apple CPUs) and Ubuntu, which supports different usage
patterns (see [the next chapter](./interacting.md)). This chapter describes the
[prerequisites](#prerequisites), [installation](#installation), and [configuration](#configuration)
of the Walrus client.

Note that our Walrus devnet uses Sui **testnet** for coordination.

## Prerequisites

Interacting with Walrus requires a valid Sui **testnet** wallet with some amount of SUI tokens. The
easiest way to set this up is via the Sui CLI; see the [installation
instructions](https://docs.sui.io/guides/developer/getting-started/sui-install) in the Sui
documentation.

After installing the Sui CLI, you need to set up a testnet wallet by running `sui client`, which
prompts you to set up a new configuration. You can use the full node at
`https://fullnode.testnet.sui.io:443`. See
[here](https://docs.sui.io/guides/developer/getting-started/connect) for further details.

Finally, you need to get at least two SUI testnet coins from the faucet:

```sh
sui client faucet && sui client faucet
```

The system-wide wallet will be used by Walrus if no other path is specified. If you want to use a
different Sui wallet, you can specify this in the [Walrus configuration file](#configuration) or
when [running the CLI](./interacting.md).

## Installation

We currently provide the `walrus` client binary for macOS (Intel and Apple CPUs) and Ubuntu. You can
download the latest build from our Google Cloud Storage (GCS) bucket:

```sh
SYSTEM=macos-arm64 # or macos-x86_64 or ubuntu-x86_64
curl https://storage.googleapis.com/mysten-walrus-binaries/latest/walrus-latest-$SYSTEM -o walrus
chmod +x walrus
```

You can then run the CLI simply as `./walrus`, or, if it is in a different location, as
`path/to/walrus`.  Alternatively, you can also place it into any directory that is in your `$PATH`
and run it as `walrus`. See [the next chapter](./interacting.md) for further details on how to use
it.

In addition to the latest version of the `walrus` binary, the GCS bucket also contains previous
versions. An overview in XML format is available at
<https://storage.googleapis.com/mysten-walrus-binaries/>.

## Configuration

### Configuration file

You can configure the Walrus client through a `client_config.yaml` file. By default, the CLI will
look for it in the current directory or in `~/.walrus/`, but you can specify a custom path through
the `--client` option.

The configuration file currently supports the following parameters:

```yaml
# This is the only mandatory field. The system object is specific for a particular Walrus
# deployment.
#
# NOTE: THE VALUE INCLUDED HERE IS AN EXAMPLE VALUE.
# You can get the object ID for the current Walrus devnet deployment as described below.
system_object: 0x3243f6a8885a308d313198a2e03707344a4093822299f31d0082efa98ec4e6c8

# You can define a custom path to your Sui wallet configuration here. If this is unset or `null`,
# the wallet is configured from `./sui_config.yaml` (relative to your current working directory), or
# the system-wide wallet at `~/.sui/sui_config/client.yaml` in this order.
wallet_config: null

# The following parameters can be used to tune the networking behavior of the client. There is no
# risk in playing around with these values. In the worst case, you may not be able to store/read
# blob due to timeouts or other networking errors.
communication_config:
  max_concurrent_writes: null
  max_concurrent_sliver_reads: null
  max_concurrent_metadata_reads: 3
  max_concurrent_status_reads: null
  reqwest_config:
    total_timeout:
      secs: 180
      nanos: 0
    pool_idle_timeout: null
    http2_keep_alive_timeout:
      secs: 5
      nanos: 0
    http2_keep_alive_interval:
      secs: 30
      nanos: 0
    http2_keep_alive_while_idle: true
  request_rate_config:
    max_node_connections: 10
    max_retries: 5
    min_backoff:
      secs: 2
      nanos: 0
    max_backoff:
      secs: 60
      nanos: 0
```

### System object ID

You can get the system object ID of the current devnet deployment as follows:

```sh
curl https://storage.googleapis.com/mysten-walrus-binaries/walrus-configs/client_config.yaml
```

If you want, you can directly store this as a configuration file:

```sh
curl https://storage.googleapis.com/mysten-walrus-binaries/walrus-configs/client_config.yaml -o client_config.yaml
```

**Important**: Make sure your wallet is set up for Sui **testnet**.
