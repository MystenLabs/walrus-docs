# Installing the site builder

This section describes the steps necessary to setup the Walrus Sites' `site-builder` tool and
prepare your environment for development.

## Prerequisites

Before you start, make sure you

- have a recent version of [Rust](https://www.rust-lang.org/tools/install) installed;
- have `git` installed; and
- followed all [Walrus setup instructions](../usage/setup.md).

Then, follow these additional setup steps.

## Clone the repository and build the `site-builder` tool

First, clone and enter the Walrus Sites repo from <https://github.com/MystenLabs/walrus-sites>:

``` sh
git clone https://github.com/MystenLabs/walrus-sites.git
cd walrus-sites
```

Then, build the release version of the site builder:

``` sh
cargo build --release
```

After the build process completes, you are ready to run the site builder:

```terminal
$ ./target/release/site-builder
Usage: site-builder [OPTIONS] <COMMAND>

Commands:
  publish  Publish a new site on Sui
  update   Update an existing site
  convert  Convert an object ID in hex format to the equivalent Base36
               format
  sitemap  Show the pages composing the Walrus site at the given object ID
  help     Print this message or the help of the given subcommand(s)

⋮
```
