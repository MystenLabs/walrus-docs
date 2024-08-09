# JSON mode

All Walrus client commands (except, currently, the `info` command) are also available in JSON mode.
In this mode, all the command-line flags of the original CLI command can be specified in JSON
format. The JSON mode therefore simplifies programmatic access to the CLI.

For example, to store a blob, run:

```sh
walrus json \
    '{
        "config": "path/to/client_config.yaml",
        "command": {
            "store": {
                "file": "README.md"
            }
        }
    }'
```

Or, to read a blob knowing the blob ID:

```sh
walrus json \
    '{
        "config": "path/to/client_config.yaml",
        "command": {
            "read": {
                "blobId": "4BKcDC0Ih5RJ8R0tFMz3MZVNZV8b2goT6_JiEEwNHQo"
            }
        }
    }'
```

All options, default values, and commands are equal to those of the "standard" CLI mode, except that
they are written in "camelCase" instead of "kebab-case".

The `json` command also accepts input from `stdin`.

The output of a `json` command will itself be JSON-formatted, again to simplify parsing the results
in a programmatic way. For example, the JSON output can be piped to the `jq` command for parsing and
manually extracting relevant fields.
