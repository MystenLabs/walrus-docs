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

Finally, make sure you have at least one gas coin with at least 1 SUI. You can obtain one from the
Testnet faucet:

```sh
sui client faucet
```

After some seconds, you should see your new SUI coins:

```terminal
$ sui client gas
╭─────────────────┬────────────────────┬──────────────────╮
│ gasCoinId       │ mistBalance (MIST) │ suiBalance (SUI) │
├─────────────────┼────────────────────┼──────────────────┤
│ 0x65dca966dc... │ 1000000000         │ 1.00             │
╰─────────────────┴────────────────────┴──────────────────╯
```

The system-wide wallet will be used by Walrus if no other path is specified. If you want to use a
different Sui wallet, you can specify this in the [Walrus configuration file](#configuration) or
when [running the CLI](./interacting.md).

## Installation

We currently provide the `walrus` client binary for macOS (Intel and Apple CPUs) and Ubuntu:

| OS     | CPU                   | Architecture                                                                                                         |
| ------ | --------------------- | -------------------------------------------------------------------------------------------------------------------- |
| MacOS  | Apple Silicon         | [`macos-arm64`](https://storage.googleapis.com/mysten-walrus-binaries/walrus-latest-macos-arm64)                     |
| MacOS  | Intel 64bit           | [`macos-x86_64`](https://storage.googleapis.com/mysten-walrus-binaries/walrus-latest-macos-x86_64)                   |
| Ubuntu | Intel 64bit           | [`ubuntu-x86_64`](https://storage.googleapis.com/mysten-walrus-binaries/walrus-latest-ubuntu-x86_64)                 |
| Ubuntu | Intel 64bit (generic) | [`ubuntu-x86_64-generic`](https://storage.googleapis.com/mysten-walrus-binaries/walrus-latest-ubuntu-x86_64-generic) |

You can download the latest build from our Google Cloud Storage (GCS) bucket (correctly setting the
`$SYSTEM` variable)`:

```sh
SYSTEM=ubuntu-x86_64 # or macos-x86_64 or macos-arm64
curl https://storage.googleapis.com/mysten-walrus-binaries/walrus-latest-$SYSTEM -o walrus
chmod +x walrus
```

On Ubuntu, you should generally use the `ubuntu-x86_64` version. However, this is incompatible with
old hardware and certain virtualized environments (throwing an "Illegal instruction (core dumped)"
error); in these cases you can use the `ubuntu-x86_64-generic` version.

To be able to run it simply as `walrus`, move the binary to any directory included in your `$PATH`
environment variable. Standard locations are `/usr/local/bin/`, `$HOME/bin/`, or
`$HOME/.local/bin/`.

```admonish warn
Previously, this guide recommended placing the binary in `$HOME/.local/bin/`. If you install the
latest binary somewhere else, make sure to clean up old versions. You can find the binary in use by
calling `which walrus`.
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
mkdir -p ~/.config/walrus
curl https://storage.googleapis.com/mysten-walrus-binaries/walrus-configs/client_config.yaml \
     -o ~/.config/walrus/client_config.yaml
```

### Custom path (optional) {#config-custom-path}

By default, the Walrus client will look for the `client_config.yaml` (or `client_config.yml`)
configuration file in the current directory, `$XDG_CONFIG_HOME/walrus/`, `~/.config/walrus/`, or
`~/.walrus/`. However, you can place the file anywhere and name it anything you like; in this case
you need to use the `--config` option when running the `walrus` binary.

### Advanced configuration (optional)

The configuration file currently supports the following parameters:

```yaml
# This is the only mandatory field. The system object is specific for a particular Walrus
# deployment.
#
# NOTE: THE VALUE INCLUDED HERE IS AN EXAMPLE VALUE.
# You can get the object ID for the current Walrus Devnet deployment as described above.
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
