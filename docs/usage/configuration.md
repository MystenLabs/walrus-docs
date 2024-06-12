# Configuration

## Configuration file

You can configure the Walrus client through a `client_config.yaml` file. By default, the CLI will
look for it in the current directory or in `~/.walrus/`, but you can specify a custom path through
the `--client` option.

The configuration file currently supports the following parameters:

```yaml
# This is the only mandatory field. The system object is specific for a particular Walrus
# deployment. This is an example value; you can get the object ID for the current devnet deployment
# as described below.
system_object: 0x3243f6a8885a308d313198a2e03707344a4093822299f31d0082efa98ec4e6c8

# You can define a custom path to your Sui wallet configuration here. If this is unset or `null`,
# the wallet is configured from `./sui_config.yaml` (relative to your current working directory), or
# the system-wide wallet at `~/.sui/sui_config/client.yaml` in this order.
wallet_config: null

# The following parameters can be used to tune the networking behavior of the client. There is no
# risk in playing around with these values. In the worst case, you may not be able to store/read
# blob due to timeouts or other networking errors.
communication_config:
  max_concurrent_writes: null
  max_concurrent_sliver_reads: null
  max_concurrent_metadata_reads: 3
  max_concurrent_status_reads: null
  reqwest_config:
    total_timeout:
      secs: 180
      nanos: 0
    pool_idle_timeout: null
    http2_keep_alive_timeout:
      secs: 5
      nanos: 0
    http2_keep_alive_interval:
      secs: 30
      nanos: 0
    http2_keep_alive_while_idle: true
  request_rate_config:
    max_node_connections: 10
    max_retries: 5
    min_backoff:
      secs: 2
      nanos: 0
    max_backoff:
      secs: 60
      nanos: 0
```

## System object ID

You can get the system object ID of the current devnet deployment as follows:

```sh
curl https://storage.googleapis.com/mysten-walrus-binaries/walrus-configs/client_config.yaml
```

If you want, you can directly store this as a configuration file:

```sh
curl https://storage.googleapis.com/mysten-walrus-binaries/walrus-configs/client_config.yaml -o client_config.yaml
```
