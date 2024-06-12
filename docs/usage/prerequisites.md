# Prerequisites

Interacting with Walrus requires a valid Sui testnet wallet with some amount of SUI tokens. The
easiest way to set this up is via the Sui CLI; see the [installation
instructions](https://docs.sui.io/guides/developer/getting-started/sui-install) in the Sui
documentation.

After installing the Sui CLI, you need to set up a testnet wallet by running `sui client`, which
prompts you to set up a new configuration. You can use the full node at
`https://fullnode.testnet.sui.io:443`. See
[here](https://docs.sui.io/guides/developer/getting-started/connect) for further details.

Finally, you need to get testnet SUI tokens from the faucet:

```sh
sui client faucet
```

The system-wide wallet will be used by Walrus if no other path is specified. If you want to use a
different Sui wallet, you can specify this in the [Walrus configuration file](./configuration.md) or
when [running the CLI](./interacting.md).
