# Publishing a Walrus Site

Now that everything is installed and configured, you should be able to start publishing
your first Walrus Site!

## Select the source material for the site

The `site-builder` works by uploading a directory of files produced by any web framework to Walrus
and adding the relevant metadata to Sui. This directory should have a file called `index.html` in
its root, which will be the entry point to the Walrus Site.

For the rest of the tutorial, we will use as an example the simple site contained in
`./examples/snake`.

## Publish the site

Since we have placed the `walrus` binary and configuration in their default locations, publishing
the `./examples/snake` site is as simple as calling the publishing command:

``` sh
./target/release/site-builder --config site-builder/assets/builder-example.yaml publish ./examples/snake
```

The output should look like the following:

``` txt
Operations performed:
- created resource /Oi-Regular.ttf with blob ID 2YLU3Usb-WoJAgoNSZUNAFnmyo8cfV8hJYt2YdHL2Hs
- created resource /file.png with blob ID R584P82qm4Dn8LoQMlzkGZS9IAkU0lNZTVlruOsUyOs
- created resource /index.html with blob ID SSzbpPfO2Tqk6xNyF1i-NG9I9CjUjuWnhUATVSs5nic
- created resource /walrus.png with blob ID SGrrw5NQyFWtqtxzLAQ1tLpcChGc0VNbtFRhfsQPuiM

Created new site: test site
New site object ID: 0x5ac988828a0c9842d91e6d5bdd9552ec9fcdddf11c56bf82dff6d5566685a31e

Browse the resulting site at: https://29gjzk8yjl1v7zm2etee1siyzaqfj9jaru5ufs6yyh1yqsgun2.walrus.site
```

This output tells you that, for each file in the folder, a new Walrus blob was created, and the
respective blob ID. Further, it prints the object ID of the Walrus Site object on Sui (so you can
have a look in the explorer and use it to set the SuiNS name) and, finally, the URL at which you
can browse the site.

Note here that we are passing the example config `assets/builder-example.yaml` as the config for the
site builder. The configuration file is necessary to ensure that the `site-builder` knows the
correct Sui package for the Walrus Sites logic.

More details on the configuration of the `site-builder` can be found under the [advanced
configuration](tutorial-config.md) section.

## Update the site

Let's say now you want to update the content of the site, for example by changing the title from
"eat all the blobs!" to "Glob all the Blobs!".

First, make this edit on in the `./examples/snake/index.html` file.

Then, you can update the existing site by running the `update` command, providing the directory
where to find the updated files (still `./example/snake`) and the object ID of the existing site
(`0x5ac988...`):

``` sh
./target/release/site-builder --config site-builder/assets/builder-example.yaml update ./examples/snake 0x5ac9888...
```

The output this time should be:

``` txt
Operations performed:
  - deleted resource /index.html with blob ID SSzbpPfO2Tqk6xNyF1i-NG9I9CjUjuWnhUATVSs5nic
  - created resource /index.html with blob ID LXtY0VdY5kM-3Ph7gLvj8URdz5yiRa5DUy3ZxYqDView

Updated site at object ID: 0x5ac988828a0c9842d91e6d5bdd9552ec9fcdddf11c56bf82dff6d5566685a31e

Browse the resulting site at: https://29gjzk8yjl1v7zm2etee1siyzaqfj9jaru5ufs6yyh1yqsgun2.walrus.site
```

Compared to the `publish` action, we can see that now the only actions performed were to delete the
old `index.html`, and update it with the newer one.

Browsing to the provided URL should reflect the change. You've updated the site!

```admonish note
The wallet you are using must be the *owner* of the Walrus Site object to be able to update it.
```

## Additional commands

The `site-builder` tool provides two additional utilities:

- The `convert` command converts an object ID in hex format to the equivalent Base36
  format. This command is useful if you have the Sui object ID of a Walrus Site, and want to know
  the subdomain where you can browse it.
- The `sitemap` command shows the resources that compose the Walrus Site at the given object ID.

```admonish tip
In general, the `--help` flag is your friend, you can add it to get further details for the whole
CLI (`./target/release/site-builder --help`) or individual commands (e.g.,
`./target/release/site-builder update --help`).
```
