# Configuring the site builder

Configuring the `site-builder` tool is straightforward, but care is required to ensure that
everything works correctly.

The `site-builder` tool requires a configuration file to know which package to use on Sui, which
wallet to use, the gas budget, and other operational details. Most of these are abstracted away
through sensible defaults, so you should not need to touch them. Yet, for completeness, we provide
here the details for all the configuration options.

## Minimal configuration

The config file is expected to be in `./builder.yaml`, and it is possible to point elsewhere with
the `--config` flag. For your first run, it should be sufficient to call the `site-builder` with
`--config site-builder/assets/builder-example.yaml`, which is already configured appropriately.

If, for any reason, you didn't add `walrus` to `$PATH`, make sure to configure a pointer to the
binary, see below.

## Advanced configuration

If you want to have more control over the behavior of the site builder, you can customize the
following variables in the config file:

- `package`: the object ID of the Walrus Sites package on Sui. This must always be specified in the
  config, and is already appropriately configured in `assets/example-config.yaml`.
- `portal`: the name of the Portal through which the site will be viewed; this only affects the
  output of the CLI, and nothing else (default: `walrus.site`).
  All Walrus Sites are accessible through any Portal independent of this setting.
- `general`: these are general options that can be configured both through the CLI and the config:
  - `rpc_url`: The URL of the Sui RPC node to use. If not set, the `site-builder` will infer it from
    the wallet.
  - `wallet`: Pointer to the Sui wallet to be used. By default, it uses the system-wide wallet (the
    one from `sui client addresses`).
  - `walrus_binary`: Pointer to the `walrus` binary. By default, this is expected to be run from
    `$PATH`.
  - `walrus_config`: The configuration for the `walrus` client binary, see the [relevant
    chapter](../usage/setup.md).
  - `gas_budget`: The maximum amount of gas to be spent for transactions (default: 500M MIST).
