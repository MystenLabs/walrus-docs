# Using the Walrus client

The `walrus` binary can be used to interact with Walrus as a client. See the [setup
chapter](./setup.md) for prerequisites, installation, and configuration.

Detailed usage information is available through

```sh
walrus --help
```

Storing and reading blobs from Walrus can be achieved through the following commands:

```sh
walrus store <some file>
walrus read <some blob ID>
```

Information about the Walrus system is available through through the `walrus info` command.

Use the `--config` option to specify a custom path to the configuration location.

If you get an error like "the specified Walrus system object does not exist", make sure your wallet
is set up for Sui **testnet** and you use the latest [configuration](./configuration.md).
