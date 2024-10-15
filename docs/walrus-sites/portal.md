# The Walrus Sites Portal

We use the term "Portal" to indicate any technology that is used to access an browse Walrus Sites.
As mentioned in the [overview](./overview.md#the-site-rendering-path), we foresee three kinds of
Portals:

1. server-side Portals;
1. custom local apps; and
1. service-worker based Portals in the browser.

Currently, the server-side and service-workers Portals are available at <https://blob.store> and
<https://walrus.site>, respectively.

## Running the Portal locally

You can run a service-worker Portal locally if you want to browse Walrus Sites without accessing
external Portals or for development purposes.

This requires having the [`pnpm`](https://pnpm.io/) tool installed. To start, clone the
`walrus-sites` repo and enter the `portal` directory. Here, run

``` sh
cd portal
pnpm install
# Build the portal you want to use, or both
pnpm build:worker
pnpm build:server
```

to install the dependencies, and then either one of the following commands:

``` sh
# Serve the server-side Portal
pnpm serve:dev:server

# Serve the service-worker Portal
pnpm serve:dev:worker
```

to serve one of the Portals. Typically, you will find it served at `localhost:8080` (but check the
output of the serve command).

For the production versions, use the `prod` commands: `serve:prod:server` and `serve:prod:worker`.

## Configuring the Portal

The most important configuration parameters for the Portal are in `portal/common/lib/constants.ts`:

- `NETWORK`: The Sui network to be used for fetching the Walrus Sites objects. Currently, we
  use Sui `testnet`.
- `AGGREGATOR`: The URL of the [aggregator](../usage/web-api.md) from which the service worker will
  fetch the Walrus blobs.
- `SITE_PACKAGE`: The Sui object ID of the Walrus Sites package.
- `MAX_REDIRECT_DEPTH`: The number of [redirects](./redirects.md) the service worker will follow
  before stopping.
- `SITE_NAMES`: Hard coded `name: objectID` mappings, to override the SuiNS names. For development
  only.
