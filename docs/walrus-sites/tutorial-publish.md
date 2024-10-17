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
./target/release/site-builder publish ./examples/snake --epochs 100
```

``` admonish tip
Currently on Walrus testnet, the duration of an epoch is 1 day. If you want your site to stay up
longer, specify the number of epochs with the `--epochs` flag!
```

```admonish note
The site builder will look for the default configuration file `sites-config.yaml` in the
`./walrus-sites` directory. In case you are calling the `site-builder` command from a different
location, use the `--config` flag to specify the path to the configuration file.
```

The end of the output should look like the following:

``` txt
Execution completed
Resource operations performed:
  - created resource /Oi-Regular.ttf with blob ID 76npyqDyGF10-jP_ov-UBHpi-RaRFnxcWgslueGEfr0
  - created resource /file.svg with blob ID w70pYgtLmi--38Jg1sTGaLlZkQtximNMHXjxDQdXKa0
  - created resource /index.html with blob ID LVLk9VSnBrEgQ2HJHAgU3p8IarKypQpfn38aSeUZzzE
  - created resource /walrus.svg with blob ID 866UDjMAy_BB8SsTcgjGEOFp2uAO9BbcVbLh5-_oBNE
The site routes were modified

Created new site: test site
New site object ID: 0x407a308190eb82b266be9cc28b888d04c5b2e5a503c7d0ffd3f69681ea83b73a
Browse the resulting site at: https://1lupgq2auevjruy7hs9z7tskqwjp5cc8c5ebhci4v57qyl4piy.walrus.site
```

This output tells you that, for each file in the folder, a new Walrus blob was created, and the
respective blob ID. Further, it prints the object ID of the Walrus Site object on Sui (so you can
have a look in the explorer and use it to set the SuiNS name) and, finally, the URL at which you
can browse the site.

Note here that we are passing the default config `./sites-config.yaml` as the config for the site
builder. The configuration file is necessary to ensure that the `site-builder` knows the correct Sui
package for the Walrus Sites logic.

More details on the configuration of the `site-builder` can be found under the [advanced
configuration](./builder-config.md) section.

## Update the site

Let's say now you want to update the content of the site, for example by changing the title from
"eat all the blobs!" to "Glob all the Blobs!".

First, make this edit on in the `./examples/snake/index.html` file.

Then, you can update the existing site by running the `update` command, providing the directory
where to find the updated files (still `./example/snake`) and the object ID of the existing site
(`0x407a3081...`):

``` sh
./target/release/site-builder update --epochs 100 examples/snake  0x407a3081...
```

The output this time should be:

``` txt
Execution completed
Resource operations performed:
  - deleted resource /index.html with blob ID LVLk9VSnBrEgQ2HJHAgU3p8IarKypQpfn38aSeUZzzE
  - created resource /index.html with blob ID pcZaosgEFtmP2d2IV3QdVhnUjajvQzY2ev8d9U_D5VY
The site routes were left unchanged

Site object ID: 0x407a308190eb82b266be9cc28b888d04c5b2e5a503c7d0ffd3f69681ea83b73a
Browse the resulting site at: https://1lupgq2auevjruy7hs9z7tskqwjp5cc8c5ebhci4v57qyl4piy.walrus.site
```

Compared to the `publish` action, we can see that now the only actions performed were to delete the
old `index.html`, and update it with the newer one.

Browsing to the provided URL should reflect the change. You've updated the site!

```admonish note
The wallet you are using must be the *owner* of the Walrus Site object to be able to update it.
```
