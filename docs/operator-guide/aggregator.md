# Aggregator node

Below is an example of an Aggregator node which hosts a HTTP endpoint that can be used to fetch data from Walrus over the web.

The aggregator process is run via the [Walrus CLI](../usage/client-cli.md). It can be run in many ways,
one example being via a systemd service.

```
[Unit]
Description=Walrus Aggregator Node

[Service]
User=walrus
Environment=RUST_BACKTRACE=1
Environment=RUST_LOG=info,walrus=debug
ExecStart=/opt/walrus/bin/walrus --config /opt/walrus/config/client_config.yaml aggregator --bind-address 0.0.0.0:9000
Restart=always

LimitNOFILE=65536
```

More documentation on running a web api version of the aggregator can be found in the [usage guide](../usage/web-api.md).
