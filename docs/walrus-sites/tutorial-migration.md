# Migrating your site from Devnet to Testnet

The migration of a Walrus Site from the Devnet to the Testnet is a very simple manual process.
This is required because both the storage backing the sites (Walrus) and the contracts on Sui
implementing the Walrus Sites functionality have been updated.

``` admonish tip
The migration will result in a new Site object on Sui (with a different object ID), and new blob
objects on Walrus testnet.
```

The steps are the following:

- Get the latest version of the `walrus` binary, as well as the latest Walrus
  configuration file, following the [Walrus installation
  instructions](../usage/setup.md).
- Ensure you have the latest version of the `site-builder` binary by following the [installation
  instructions](./tutorial-install.md) again. Remember to `git pull` if you are building from the
  repo and have cloned it previously. Pulling the repo also guarantees you have the latest
  sites configuration file, pointing to the correct contracts.
- Run the `site-builder` with the `publish` command on your site directory. This will create a new
  Walrus Site object on Sui, using the new contracts, and store the site files anew on Walrus
  Testnet. Note that this operation will create a new object ID for your site!
- Optional: If you had set up a SuiNS name for your site, you will need to point the name to the new
  site's object ID. See the [tutorial on setting a SuiNS name](./tutorial-suins.md) for more
  details.
