# The Walrus decentralized blob storage system

Welcome to the GitHub repository for Walrus, a decentralized storage and availability protocol
designed specifically for large binary files, or "blobs". Walrus focuses on providing a robust
solution for storing unstructured content on decentralized storage nodes while ensuring high
availability and reliability even in the presence of Byzantine faults.

## Documentation

Our documentation is available [as a Walrus Site](https://docs.walrus.site) (see [the
documentation](https://docs.walrus.site/walrus-sites/intro.html) for further information on what
this means) and on [GitHub Pages](https://mystenlabs.github.io/walrus-docs); it is generated using
[mdBook](https://rust-lang.github.io/mdBook/) from source files in the [`docs/`](./docs/) directory.

You can also build and access the documentation locally (assuming you have Rust installed):

```sh
cargo install mdbook
cargo install mdbook-admonish@1.18.0 --locked
cargo install mdbook-katex@0.9.0 --locked
mdbook serve
```

## Get help and report issues

If you have general questions or require help on how to use Walrus, please check for [existing
discussions](https://github.com/MystenLabs/walrus-docs/discussions). If your question is not
answered yet, you can [open a new
discussion](https://github.com/MystenLabs/walrus-docs/discussions/new?category=q-a).

If you experience any issues or bugs, please [check for existing
issues](https://github.com/MystenLabs/walrus-docs/issues) and [file an
issue](https://github.com/MystenLabs/walrus-docs/issues/new) if it hasn't been reported yet.

## License

This project is licensed under the Apache License, Version 2.0 ([LICENSE](LICENSE) or
<https://www.apache.org/licenses/LICENSE-2.0>).
