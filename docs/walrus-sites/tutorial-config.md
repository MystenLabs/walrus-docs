# Configuring the site builder

Configuring the `site-builder` tool is straightforward, but care is required to ensure that
everything works correctly.

The `site-builder` tool requires a configuration file to know which package to use on Sui, which
wallet to use, the gas budget, and other operational details. Most of these are abstracted away
through sensible defaults, so you should not need to touch them. Yet, for completeness, we provide
here the details for all the configuration options.

## Minimal configuration

The config file is expected to be in `./config.yaml`, and it is possible to point elsewhere with the
`--config` flag.  For your first run, it should be sufficient to call the `site-builder` with
`--config assets/config-example.yaml`, which is already configured appropriately

## Advanced configuration

If you want to have more control over the behavior of the site builder, you can customize the
following variables in the config file:

- `package`: the object ID of the Walrus Sites package on Sui. This must always be specified in the
  config, and is already appropriately configured in `assets/example-config.yaml`.
- `module`: the name of the module in the Walrus Sites package [default: `site`].
- `portal`: the name of the portal through which the site will be viewed; this only affects the
  output of the CLI, and nothing else [default: `walrus.site`].
- `general`: these are general options, that can be configured both through the CLI and the config:
  - `rpc_url`: The URL of the RPC to use. If not set, the `site-builder` will infer it from the wallet.
  - `wallet`: Pointer to the Sui wallet to be used. By default, it uses???
  - `walrus_binary`: Pointer to the `walrus` binary. By default, this is expected to be run from `$PATH`.
  - `walrus_config`: The configuration for the `walrus` client binary. See [the relative documentation](TODO: link).
  - `gas_budget`: The maximum amount of gas to be spent for transactions [default: 500M MIST].
  - `gas_coin`: The gas coin to be used to pay for the transaction (TODO: remove).
