# Setup

At this stage of the project, our Walrus code is not yet public. Instead, we provide a pre-compiled
`walrus` client binary for macOS (Intel and Apple CPUs) and Ubuntu, which supports different usage
patterns (see [the next chapter](./interacting.md)). This chapter describes the
[prerequisites](#prerequisites), [installation](#installation), and [configuration](#configuration)
of the Walrus client.

```admonish note
Note that our Walrus Devnet uses Sui **Testnet** for coordination.
```

## Prerequisites

Interacting with Walrus requires a valid Sui **Testnet** wallet with some amount of SUI tokens. The
easiest way to set this up is via the Sui CLI; see the [installation
instructions](https://docs.sui.io/guides/developer/getting-started/sui-install) in the Sui
documentation.

After installing the Sui CLI, you need to set up a Testnet wallet by running `sui client`, which
prompts you to set up a new configuration. Make sure to point it to Sui Testnet, you can use the
full node at `https://fullnode.testnet.sui.io:443` for this. See
[here](https://docs.sui.io/guides/developer/getting-started/connect) for further details.

If you already have a Sui wallet configured, you can directly set up the Testnet environment (if you
don't have it yet),

```sh
sui client new-env --alias testnet --rpc https://fullnode.testnet.sui.io:443
```

and switch the active environment to it:

```sh
sui client switch --env testnet
```

After this, you should get something like this (everything besides the `testnet` line is optional):

```terminal
$ sui client envs
╭──────────┬─────────────────────────────────────┬────────╮
│ alias    │ url                                 │ active │
├──────────┼─────────────────────────────────────┼────────┤
│ devnet   │ https://fullnode.devnet.sui.io:443  │        │
│ localnet │ http://127.0.0.1:9000               │        │
│ testnet  │ https://fullnode.testnet.sui.io:443 │ *      │
│ mainnet  │ https://fullnode.mainnet.sui.io:443 │        │
╰──────────┴─────────────────────────────────────┴────────╯
```

Finally, make sure you have at least 2 separate gas coins, with at least 1 SUI each. You can obtain
these coins from the Testnet faucet:

```sh
sui client faucet && sui client faucet
```

After some seconds, you should see your new SUI coins:

```terminal
$ sui client gas
╭─────────────────┬────────────────────┬──────────────────╮
│ gasCoinId       │ mistBalance (MIST) │ suiBalance (SUI) │
├─────────────────┼────────────────────┼──────────────────┤
│ 0x65dca966dc... │ 1000000000         │ 1.00             │
│ 0xb07a091c1f... │ 1000000000         │ 1.00             │
╰─────────────────┴────────────────────┴──────────────────╯
```

The system-wide wallet will be used by Walrus if no other path is specified. If you want to use a
different Sui wallet, you can specify this in the [Walrus configuration file](#configuration) or
when [running the CLI](./interacting.md).

## Installation

We currently provide the `walrus` client binary for macOS (Intel and Apple CPUs) and Ubuntu:

| OS     | CPU           | Architecture                                                                                                |
| ------ | ------------- | ----------------------------------------------------------------------------------------------------------- |
| MacOS  | Apple Silicon | [`macos-arm64`](https://storage.googleapis.com/mysten-walrus-binaries/latest/walrus-latest-macos-arm64)     |
| MacOS  | Intel 64bit   | [`macos-x86_64`](https://storage.googleapis.com/mysten-walrus-binaries/latest/walrus-latest-macos-x86_64)   |
| Ubuntu | Intel 64bit   | [`ubuntu-x86_64`](https://storage.googleapis.com/mysten-walrus-binaries/latest/walrus-latest-ubuntu-x86_64) |

You can download the latest build from our Google Cloud Storage (GCS) bucket (correctly setting the
`$SYSTEM` variable) and move it to a directory included in your `$PATH`:

```sh
SYSTEM=ubuntu-x86_64 # or macos-x86_64 or macos-arm64
curl https://storage.googleapis.com/mysten-walrus-binaries/latest/walrus-latest-$SYSTEM -o walrus
chmod +x walrus
mv walrus ~/.local/bin
```

Once this is done, you should be able to simply type `walrus` in your terminal. For example you can
get usage instructions (see [the next chapter](./interacting.md) for further details):

```terminal
$ walrus --help
Walrus client

Usage: walrus [OPTIONS] <COMMAND>

Commands:
⋮
```

```admonish tip
Our latest Walrus binaries are also available on Walrus itself, namely on <https://bin.walrus.site>.
Note, however, that you can only access this through a web browser and not through CLI tools like
cURL due to the service-worker architecture (see the [Walrus Sites docs](../walrus-sites/portal.md)
for further insights).
```

### Custom path (optional) {#binary-custom-path}

Instead of `~/.local/bin`, you can place the binary in any other directory you like. You need to
either make sure to add that directory to your `$PATH` or always call the binary as
`/full/path/to/walrus`.

### Previous versions (optional)

In addition to the latest version of the `walrus` binary, the GCS bucket also contains previous
versions. An overview in XML format is available at
<https://storage.googleapis.com/mysten-walrus-binaries/>.

## Configuration

A single parameter is required to configure Walrus, namely the ID of the [system
object](../dev-guide/sui-struct.md#system-information) on Sui. You can create your client
configuration as follows:

<!-- TODO: Make sure this is consistent with our default paths. -->
```sh
mkdir ~/.walrus
curl https://storage.googleapis.com/mysten-walrus-binaries/walrus-configs/client_config.yaml \
     -o ~/.walrus/client_config.yaml
```

### Custom path (optional) {#config-custom-path}

By default, the Walrus client will look for the `client_config.yaml` configuration file in the
current directory or in `~/.walrus/`, but you can place the file anywhere and name it anything you
like; in this case you need to use the `--config` option when running the `walrus` binary.

### Advanced configuration (optional)

The configuration file currently supports the following parameters:

```yaml
# This is the only mandatory field. The system object is specific for a particular Walrus
# deployment.
#
# NOTE: THE VALUE INCLUDED HERE IS AN EXAMPLE VALUE.
# You can get the object ID for the current Walrus devnet deployment as described above.
system_object: 0x3243....

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

```admonish warning title="Important"
If you specify a wallet path, make sure your wallet is set up for Sui **Testnet**.
```
