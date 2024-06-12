# Installing the site builder

We describe here the steps necessary to setup the Walrus Sites' `site-builder` tool, and prepare
your environment for development.

## Prerequisites

Before you start, make sure you:

- Have a recent version of [Rust](https://www.rust-lang.org/tools/install) installed; and
- have the [Sui CLI](https://docs.sui.io/guides/developer/getting-started/sui-install) installed.

Then, follow these additional setup steps.

## Get the `walrus` binary and install it

Download the latest `walrus` binary for your architecture from
`https://storage.googleapis.com/mysten-walrus-binaries/walrus-v0.1.0-a0fb8c9-<arch>`, where `<arch>`
is your architecture. The available options are listed in this table:

| OS     | CPU           | Architecture    |
|--------|---------------|-----------------|
| MacOS  | Apple Silicon | `macos-arm64`   |
| MacOS  | Intel 64bit   | `macos-x86_64`  |
| Ubuntu | Intel 64bit   | `ubuntu-x86_64` |

Then, add it to your `$PATH`. For example, on MacOS you can copy it to
`/Users/myusername/.local/bin/` (check what directories are in your `$PATH` by running `echo
$PATH`).

Once this is done, you should be able to type `walrus` in your terminal and see:

``` txt
Walrus client

Usage: walrus [OPTIONS] <COMMAND>

⋮
```

If, for any reason, you don't want to add `walrus` to `$PATH`, place the binary in your preferred
directory, and remember to configure a pointer to the binary in the `site-builder` config (more on
this [later](./tutorial-config.md)).

## Point your Sui CLI to testnet, and get some SUI

Walrus is currently deployed on Sui Testnet. Therefore, you have to ensure that your Sui CLI is
configured accordingly:

``` txt
sui client envs
╭──────────┬──────────────────────────────────────┬────────╮
│ alias    │ url                                  │ active │
├──────────┼──────────────────────────────────────┼────────┤
│ devnet   │ https://fullnode.devnet.sui.io:443   │        │
│ local    │ http://127.0.0.1:9000                │        │
│ testnet  │ https://fullnode.testnet.sui.io:443/ │ *      │
│ mainnet  │ https://fullnode.mainnet.sui.io:443  │        │
╰──────────┴──────────────────────────────────────┴────────╯
```

If the `active` network is not `testnet`, switch to `testnet` by running:

``` sh
sui client switch --envs testnet
```

Further, make sure you have at least 2 separate gas coins, with at least 1 SUI each, by running `sui
client gas`.  If you don't have enough SUI, you can hit the testnet faucet by running.

``` sh
sui client faucet --url https://faucet.testnet.sui.io/v1/gas
```

After some seconds, running again `sui client gas` should show the newly-minted coins in your
wallet.

## Clone the Walrus Sites repo, and build the `site-builder` tool

First clone and enter the Walrus Sites repo from
`https://github.com/MystenLabs/blocksite-poc`). (TODO: change link to public repo when available).

``` sh
git clone git@github.com:MystenLabs/blocksite-poc.git
cd blocksite-poc
cd site-builder
```

Build the release version of the site builder.

``` sh
cargo build --release
```

After the build process completes, it should be possible to run:

``` sh
./target/release/site-builder
```

And output should look like the following:

``` txt
Usage: site-builder [OPTIONS] <COMMAND>

Commands:
  publish  Publish a new site on Sui
  update   Update an existing site
  convert  Convert an object ID in hex format to the equivalent Base36
               format
  sitemap  Show the pages composing the Walrus site at the given object ID
  help     Print this message or the help of the given subcommand(s)

Options:
  -c, --config <CONFIG>
          The path to the configuration file for the site builder [default:
          config.yaml]
      --rpc-url <RPC_URL>
          The URL or the RPC endpoint to connect the client to
      --wallet <WALLET>
          The path to the Sui Wallet config
      --walrus-binary <WALRUS_BINARY>
          The path or name of the walrus binary
      --walrus-config <WALRUS_CONFIG>
          The path to the configuration for the Walrus client
  -g, --gas-budget <GAS_BUDGET>
          The gas budget for the operations on Sui
      --gas-coin <GAS_COIN>
          The gas coin to be used
  -h, --help
          Print help (see more with '--help')
```

## Get the latest `walrus` client configuration

First,
[download](https://storage.googleapis.com/mysten-walrus-binaries/walrus-configs/client_config.yaml)
the `walrus` client config.  Then, copy it to `~/.walrus/config.yaml`. This ensures that the
`walrus` binary can connect to the correct Walrus object on Sui.
