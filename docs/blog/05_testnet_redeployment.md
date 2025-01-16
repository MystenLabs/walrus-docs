# Announcing Testnet v2

Published on: 2025-01-16

We are today redeploying the Walrus Testnet to incorporate various improvements, including some
backwards-incompatible changes. Make sure to get the latest binary and configuration as described
in the [setup section](../usage/setup.md).

Note that all blob data on the previous Testnet instance has been wiped. All blobs need to be
re-uploaded to the new Testnet instance, including Walrus Sites. In addition, there is a new version
of the WAL token, so your previous WAL tokens will not work anymore. To use the Testnet v2, you
need to obtain new WAL tokens.

In the following sections, we describe the notable changes and the actions required for existing
Walrus Sites.

## Epoch duration

The epoch duration has been increased from one day to two days to emphasize that this duration is
different from Sui epochs (at Mainnet, epochs will likely be multiple weeks long). In addition, the
maximum number of epochs a blob can be stored for has been reduced from 200 to 183 (corresponding
to one year).

The `walrus store` command now also supports the `--epochs max` flag, which will store
the blob for the maximum number of epochs. Note that the `--epochs` flag is now mandatory.

## New features

Besides many improvements to the contracts and the storage-node service, the latest Walrus release
also brings several user-facing improvements.

- The `walrus store` command now supports storing multiple files at once. This is faster and more
  cost-effective compared to storing each file separately as transactions can be batched through
  [PTBs](https://docs.sui.io/concepts/transactions/prog-txn-blocks). Notably, this is compatible
  with glob patterns offered by many shells, so you can for example run a command like `walrus store
  *.png --epochs 100` to store all PNG files in the current directory.
- The `walrus` CLI now supports creating, funding, and extending *shared blobs* using the `walrus
  share`, `walrus store --share`, and `walrus fund-shared-blob` commands. Shared blobs are an
  example of collectively managed and funded blobs. See the [shared blobs
  section](../usage/client-cli.md#shared-blobs) for more details.

## New WAL token

Along with the redeployment of Walrus, we have also deployed a fresh WAL contract. This
means that you cannot use any WAL token from the previous Testnet instance with the new Testnet
instance. You need to request new WAL tokens through the [Testnet WAL
faucet](../usage/setup.md#testnet-wal-faucet).

## Backwards-incompatible changes

One reason for a full redeployment is to allow us to make some changes that are
backwards-incompatible. Many of those are related to the contracts and thus less visible to users.
There are, however, some changes that may affect you.

### Configuration files

The format of the configuration files for storage nodes and clients has been changed. Make sure to
use the latest version of the configuration files, see the [configuration
section](../usage/setup.md#configuration).

### CLI options

Several CLI options of the `walrus` CLI have been changed. Notably, all "short" variants of options
(e.g., `-e` instead of `--epochs`) have been removed to prevent future confusion with new options.
Additionally, the `--epochs` flag is now mandatory for the `walrus store` command (this also affects
the [JSON API](../usage/json-api.md)).

Please refer to the CLI help (`walrus --help`, or `walrus <command> --help`) for further details.

### HTTP APIs

The paths, request, and response formats of the HTTP APIs have changed for the storage nodes, and
also the aggregator and publisher. Please refer to the section on the [HTTP
API](../usage/web-api.md) for further details.

## Effects on and actions required for existing Walrus Sites

The Walrus Sites contracts have not changed, which means that all corresponding objects on Sui are
still valid. However, the resources now point to blob IDs that do not yet exist on the new Testnet.
The easiest way to fix existing sites is to simply update them with the `--force` flag:

```sh
site-builder update --epochs <number of epochs> --force <path to site> <existing site object>
```

## New Move contracts & documentation

As part of the new Testnet release of Walrus, the Move smart contracts have been updated; the
deployed version can be found in the [`walrus-docs`
repository](https://github.com/MystenLabs/walrus-docs/tree/main/contracts).
