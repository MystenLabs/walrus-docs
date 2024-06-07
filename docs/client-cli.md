# Using the Walrus client

The `walrus` binary can be used to interact with Walrus as a client. To use it, you need a Walrus
configuration and a Sui wallet.
Detailed usage information is available through

```sh
walrus --help
```

Storing and reading blobs from Walrus can be achieved through the following commands:

```sh
CONFIG=working_dir/client_config.yaml # adjust for your configuration file
walrus -c $CONFIG store <some file> # store a file
walrus -c $CONFIG read <some blob ID> # read a blob
```