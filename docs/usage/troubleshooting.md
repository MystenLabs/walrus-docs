# Troubleshooting

```admonish tip title="Debug logging"
You can enable debug logging for Walrus by setting the environment variable `RUST_LOG=walrus=debug`.
```

## Latest binary

Before undertaking any other steps, make sure you have the [latest `walrus`
binary](./setup.md#installation). If you have multiple versions in different locations, find the 
binary that will actually be used with `which walrus`.

## Old hardware or incompatible VMs

Our standard Ubuntu binary is known to cause problems on certain old hardware and in certain
virtualized environments. If you experience errors like "Illegal instruction (core dumped)",
[install](./setup.md#installation) the `ubuntu-x86_64-generic` version instead, which is compiled
specifically to be compatible with almost all physical and virtual x86-64 CPUs.

## Latest Walrus configuration

The Walrus Devnet and Testnet are wiped periodically and require updating to the latest binary and
configuration. If you get an error like "could not retrieve enough confirmations to certify the
blob", you are probably using an outdated configuration pointing to an inactive Walrus system. In
this case, update your configuration file with the latest [configuration](./setup.md#configuration)
and make sure the CLI uses the intended configuration.

```admonish tip
The `walrus` client binary prints information about the used configuration when starting execution,
including the path to the Walrus configuration file and the Sui wallet.
```

## Correct Sui network configuration

If you get an error like "the specified Walrus system object does not exist", make sure your wallet
is set up for Sui **Testnet** and you use the latest [configuration](./setup.md#configuration).
