# Installation

We currently provide the `walrus` client binary for macOS (Intel and Apple CPUs) and Ubuntu. You can
download the latest build from our Google Cloud Storage (GCS) bucket:

```sh
SYSTEM=macos-arm64 # or macos-x86_64 or ubuntu-x86_64
curl https://storage.googleapis.com/mysten-walrus-binaries/latest/walrus-latest-$SYSTEM -o walrus
chmod +x walrus
```

You can then run the CLI simply as `./walrus`, or, if it is in a different location, as
`path/to/walrus`.  Alternatively, you can also place it into any directory that is in your `$PATH`
and run it as `walrus`. See [the next chapter](./interacting.md) for further details on how to use
it.

In addition to the latest version of the `walrus` binary, the GCS bucket also contains previous
versions. An overview in XML format is available at
<https://storage.googleapis.com/mysten-walrus-binaries/>.
