# Walrus Storage Node

The binary of the storage node is not yet publicly available. It will be made available in September to
operators for Testnet nodes. Prior to offical network launch the code will be open-sourced.

A basic systemd service running the Storage Node could look like this:

```
[Unit]
Description=Walrus Storage Node

[Service]
User=walrus
Environment=RUST_BACKTRACE=1
Environment=RUST_LOG=info,walrus=debug
ExecStart=/opt/walrus/bin/walrus-node run --config-path /opt/walrus/config/walrus-node.yaml
Restart=always

LimitNOFILE=65536
```

The `walrus-node` binary stores slivers in RocksDB, which means the data will be stored on disk, to a path configured by the `/opt/walrus/config/walrus-node.yaml` file.

Here are some important config params from a shortened version of the `walrus-node.yaml` config file

```
storage_path: /opt/walrus/db
metrics_address: 127.0.0.1:9184
rest_api_address: 0.0.0.0:9185
sui:
  rpc: https://fullnode.testnet.sui.io:443
  system_object: 0xWALRUS_CONTRACT
blob_recovery:
  max_concurrent_blob_syncs: 10
  retry_interval_min_secs: 1
  retry_interval_max_secs: 3600
  metadata_request_timeout_secs: 5
  max_concurrent_metadata_requests: 1
  sliver_request_timeout_secs: 300
  invalidity_sync_timeout_secs: 300
```

For monitoring, you can configure Grafana Agent to fetch metrics from `localhost:9184/metrics` (or whatever you've configured `metrics_address` to be).
