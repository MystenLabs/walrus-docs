# Operating an aggregator
<!-- (TODO - with example cache setup) -->

Below is an example of an aggregator node which hosts a HTTP endpoint that can be used
to fetch data from Walrus over the web.

The aggregator process is run via the `walrus` client binary in [daemon mode](../usage/web-api.md).
It can be run in many ways, one example being via a systemd service:

```ini
[Unit]
Description=Walrus Aggregator

[Service]
User=walrus
Environment=RUST_BACKTRACE=1
Environment=RUST_LOG=info,walrus=debug
ExecStart=/opt/walrus/bin/walrus --config /opt/walrus/config/client_config.yaml aggregator --bind-address 0.0.0.0:9000
Restart=always

LimitNOFILE=65536
```
