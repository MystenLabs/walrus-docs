# Announcing Testnet v2

Published on: 2025-01-16

We have reached a stage in development where it is beneficial to redeploy the Walrus Testnet to
incorporate various improvements that include some backwards-incompatible changes. This redeployment
has happened on 2025-01-16.

Note that all data on the previous Testnet instance has been wiped. All blobs need to be re-uploaded
to the new Testnet instance, including Walrus Sites. In addition, there is a new version of the WAL
token, so your previous WAL tokens will not work anymore. To use the Testnet v2, you need to obtain
new WAL tokens. In the following sections, we describe the notable changes and the actions required
for existing Walrus Sites.

## New features

## New WAL token

## Backwards-incompatible changes

### Configuration files

### CLI options

### HTTP APIs

## Effects on and actions required for existing Walrus Sites

The Walrus Sites contracts have not changed, meaning all corresponding objects on Sui are still
valid. However, the resources now point to blob IDs that do not yet exist on the new Testnet. The
easiest way to fix existing sites is to simply update them with the `--force` flag:

```sh
site-builder update --epochs <number of epochs> --force <path to site> <existing site object>
```

## New Move contracts & documentation

As part of the new Testnet release of Walrus, the Move smart contracts have been updated; the
deployed version can be found in the [`walrus-docs`
repository](https://github.com/MystenLabs/walrus-docs/tree/main/contracts).
