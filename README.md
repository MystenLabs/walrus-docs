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
cargo install mdbook-i18n-helpers --locked
mdbook serve
```
If you do not have Rust installed, install it using this guide:
## Installing Rust

Rust can be installed on macOS, Linux, or another Unix-like operating system using `rustup`. Follow the steps below for your respective OS.

### macOS, Linux, and Unix-like OS

1. Open your terminal.
2. Run the following command:

   ```sh
   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
   ```
### Windows

Follow the steps below to install Rust on Windows using `rustup`.

### Steps to Install

1. Visit the official [Rust website](https://www.rust-lang.org/)  
2. Download the `rustup-init.exe` installer.  
3. Run the installer.  
4. When prompted, press `1` to proceed with the default installation.  
5. Restart your Command Prompt (`cmd`) or PowerShell.  

### Verifying Installation

After installation, confirm that Rust is installed by running the following command:

```sh
rustc --version
```

### Using translated versions

If there is a translated resource in `po/` directory, it can be specified through the
`MDBOOK_BOOK__LANGUAGE` environment variable. For example, to build or serve the Chinese
translation:

```bash
MDBOOK_BOOK__LANGUAGE=zh_CN mdbook build
MDBOOK_BOOK__LANGUAGE=zh_CN mdbook serve
```

Please consult [TRANSLATING.md](./TRANSLATING.md) for further information on how to create and
maintain translations.

## Get help and report issues

If you have general questions or require help on how to use Walrus, please check for [existing
discussions](https://github.com/MystenLabs/walrus-docs/discussions). If your question is not
answered yet, you can [open a new
discussion](https://github.com/MystenLabs/walrus-docs/discussions/new?category=q-a).

If you experience any issues or bugs, please [check for existing
issues](https://github.com/MystenLabs/walrus-docs/issues) and [file an
issue](https://github.com/MystenLabs/walrus-docs/issues/new) if it hasn't been reported yet. Please
include the version of the `walrus` binary in your bug report (you can obtain it with `walrus
--version`).

## License

This project is licensed under the Apache License, Version 2.0 ([LICENSE](LICENSE) or
<https://www.apache.org/licenses/LICENSE-2.0>).
