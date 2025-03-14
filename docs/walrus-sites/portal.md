# The Walrus Sites portal

We use the term "portal" to indicate any technology that is used to access and browse Walrus Sites.
As mentioned in the [overview](./overview.md#the-site-rendering-path), we foresee three kinds of
portals:

1. server-side portals;
1. custom local apps; and
1. service-worker based portals residing in the browser.

Currently, only a server-side portal is served at <https://walrus.site>.

```admonish note title="Hosting of the service worker"
In the past, the service-worker based portal was hosted at <https://walrus.site> and the
server-portal at <https://blob.store>. This is no longer the case.

The service-worker portal is no longer hosted, but you can still run it locally. Its code is
available in the `walrus-sites` repository. For more information, see
[running the portal locally](#running-the-portal-locally).

The old domain, `blob.store` is currently an alias for `walrus.site` but will be removed in the
future.
```

```admonish danger title="Walrus Sites stable branch"
The stable branch of Walrus Sites is `testnet`.
```

## Running a local portal

You can run a portal locally if you want to browse Walrus Sites without accessing
external portals or for development purposes.

Let's start by cloning the `walrus-sites` repository:

```bash
git clone https://github.com/MystenLabs/walrus-sites.git
cd walrus-sites
```

Make sure you are on the stable branch:

``` sh
git checkout testnet
```

Next, we will see how to configure the portal and then what options are available
to run it locally.

### Configuration

Portal configuration is managed through two key elements:

- Environment variables: Required for basic functionality.
- Constants file: Optional for advanced customization.

#### Environment Variables

The environment variables are set in the `.env.local` file at the root of each portal directory.
To just run a simple instance of a portal, you can use the environment variables specified
in the `.env.example` file:

```sh
cp ./portal/server/.env.example ./portal/server/.env.local
```

Likewise, if you want to run the service-worker portal, you can copy the `.env.example` file to
`.env.local` in the `portal/worker` directory.

```sh
cp ./portal/worker/.env.example ./portal/worker/.env.local
```

#### Constants

You can find the `constants.ts` file in the `portal/common/lib` directory. It holds key
configuration parameters for the portal. Typically, you won't need to modify these, but if you do,
here are the explanations for each parameter:

- `MAX_REDIRECT_DEPTH`: The number of [redirects](./redirects.md) the portal will follow
  before stopping.
- `SITE_NAMES`: Hard coded `name: objectID` mappings, to override the SuiNS names. For development
  only. Use this at your own risk, may render some sites with legitimate SuiNS names unusable.
- `FALLBACK_PORTAL`: This is related only to the service worker portal. The fallback portal should
be a server side portal that is used in cases where some browsers do not support service workers.

### Deploying the Portal

To run the portal locally you can either use a Docker container or a local development environment.

You can run the portal via Docker for a quick setup, or use a local development environment if you
want to modify the code or contribute to the project.

#### Docker

First, make sure you have Docker installed on your system.

```sh
docker --version`
```

If it is not installed, follow the instructions on the [Docker website][get-docker].

Then, build the Docker image with:

```sh
docker build -f portal/docker/server/Dockerfile -t server-portal . --build-arg ENABLE_SENTRY=false --no-cache
```

Finally, run the Docker container:

```sh
docker run -p 3000:3000 server-portal --env-file ./portal/server/.env.local
```

Browse the sites at `localhost:3000`.

#### Local Development

This requires having the [`bun`](https://bun.sh/) tool installed:

Check if bun is installed with:

``` sh
bun --version
```

If not installed, run the following command:

```sh
curl -fsSL https://bun.sh/install | bash
```

Install the dependencies:

```sh
cd portal
bun install
```

To run a server-side portal:

```sh
bun run server
```

To run a service-worker portal:

```sh
bun build:worker
bun run worker
```

To serve one of the portals. Typically, you will find it served at `localhost:3000` (for the server
side portal) or `localhost:8080` for the service worker (but check the output of the serve
command).

[get-docker]: https://docs.docker.com/get-docker/
