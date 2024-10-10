# Devnet Update

Published on: 2024-08-12

We have redeployed the Walrus Devnet to incorporate various improvements to the Walrus storage nodes
and clients. In this process, all blobs stored on Walrus were wiped. Note that this may happen again
on Devnet and Testnet, but obviously *not on the future Mainnet*.

## Migration and Re-deployment of Walrus Sites

You can obtain the latest version of the `walrus` binary and the new configuration as described in
the [setup chapter](../usage/setup.md).

If you had deployed any Walrus Sites, the site object on Sui and any SuiNS name are still valid.
However, you need to re-store all blobs on Walrus. You can achieve this by running the site-builder
tool (from the `walrus-sites` directory) as follows:

```sh
./target/release/site-builder --config site-builder/assets/builder-example.yaml update --force \
    <path to the site> <site object ID>
```

## Changes

Besides many improvements to the storage nodes, the new version of Walrus includes the following
user-facing changes:

- Improved coin management: The client now better selects coins for gas and storage fees. Users no
  longer require multiple coins in their wallet.
- Improved connection management: The client now limits the number of parallel connections to
  improve performance for users with low network bandwidth storing large blobs.
- OpenAPI specification: Walrus storage nodes, aggregators, and publishers expose their API
  specifications at the path `/v1/api`.
- System info in JSON: The `info` command is now also available in JSON mode.
- Client version: The `walrus` CLI now has a `--version` option.
- Support for the empty blob: The empty blob is now supported by Walrus.
- Default configuration-file paths: The client now looks for configuration files in
  `~/.config/walrus` in addition to `~/.walrus` and recognizes the extension `.yml` in addition to
  `.yaml`.
- Home directory in paths: Paths specified in configuration files now expand the `~` symbol at the
  beginning to the user's home directory.
- More robust store and status check: The `store` and `blob-status` commands are now more robust
  against Sui full nodes that aggressively prune past events and against load-balancers that send
  transactions to different full nodes.
- Fix CLI parsing: The `walrus` CLI now properly handles hyphens in blob IDs.

This update also increases the number of shards to 1000, which is more representative of the
expected value in Testnet and Mainnet.
