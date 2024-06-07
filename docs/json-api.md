# JSON mode

All Walrus client commands (except, currently, the `info` command) are available in JSON mode.
In this mode, all the command line flags of the original CLI command can be specified in JSON format.
The JSON mode therefore simplifies programmatic access to the CLI.

For example, to store a blob, run:

```sh
cargo run --bin walrus -- json \
    '{
        "config": "working_dir/client_config.yaml",
        "command": {
            "store": {
                "file": "README.md"
            }
        }
    }'
```

or, to read a blob knowing the blob ID:

```sh
cargo run --bin walrus -- json \
    '{
        "config": "working_dir/client_config.yaml",
        "command": {
            "read": {
                "blob_id": "4BKcDC0Ih5RJ8R0tFMz3MZVNZV8b2goT6_JiEEwNHQo"
            }
        }
    }'
```

The `json` command also accepts input from `stdin`.

The output of a `json` command will itself be JSON-formatted, again to simplify parsing the results
in a programmatic way. For example, the JSON output can be piped to the `jq` command for parsing and
manually extracting relevant fields.
