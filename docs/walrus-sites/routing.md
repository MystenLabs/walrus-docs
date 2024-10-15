# Specifying headers and routing

``` admonish tip title="New with Walrus Sites testnet version"
The following features have been released with the Walrus Sites testnet version.
```

In its base configuration, Walrus Sites serves static assets through a Portal. However, many modern
web applications require more advanced features, such as custom headers and client-side routing.

Therefore, the site-builder can read a `ws-resource.json` configuration file, in which you can
directly specify resource headers and routing rules.

## The `ws-resources.json` file

This file is optionally placed in the root of the site directory, and it is *not* uploaded with the
site's resources (in other words, the file is not part of the resulting Walrus Site and is not
served by the Portal).

If you don't want to use this default location, you can specify the path to the configuration file
with the `--ws-resources` flag when running the `publish` or `update` commands.

The file is JSON-formatted, and looks like the following:

``` JSON
{
  "headers": {
    "/index.html": {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "max-age=3500"
    }
  },
  "routes": {
    "/*": "/index.html",
    "/accounts/*": "/accounts.html",
    "/path/assets/*": "/assets/asset_router.html"
  }
}
```

We now describe in details the two sections of the configuration file, `headers` and `routes`.

## Specifying HTTP response headers

The `headers` section allows you to specify custom HTTP response headers for specific resources.
The keys in the `headers` object are the paths of the resources, and the values are lists of
key-value pairs corresponding to the headers that the Portal will attach to the response.

For example, in the configuration above, the file `index.html` will be served with the
`Content-Type` header set to `text/html; charset=utf-8` and the `Cache-Control` header set to
`max-age=3500`.

This mechanism allows you to control various aspects of the resource delivery, such as caching,
encoding, and content types.

```admonish
The resource path is always represented as starting from the root `/`.
```

### Default headers

By default, no headers need to be specified, and the `ws-resources.json` file can be omitted. The
site-builder will automatically try to infer the `Content-Type` header based on the file extension,
and set the `Content-Encoding` to `identity` (no transformation).

In case the content type cannot be inferred, the `Content-Type` will be set to
`application/octet-stream`.

These defaults will be overridden by any headers specified in the `ws-resources.json` file.

## Specifying client-side routing

The `routes` section allows you to specify client-side routing rules for your site. This is useful
when you want to use a single-page application (SPA) framework, such as React or Angular.

The configuration in the `routes` object is a mapping from route keys to resource paths.

The **`routes` keys** are path patterns in the form `/path/to/some/*`, where the `*` character
represents a wildcard.

```admonish
Currently, the wildcard _can only be only be specified at the end of the path_.
Therefore, `/path/*` is a valid path, while `/path/*/to` and `*/path/to/*` are not.
```

The **`routes` values** are the resource paths that should be served when the route key is matched.

```admonish danger title="Important"
The paths in the values **must** be valid resource paths, meaning that they must be present among
the site's resources. The Walrus sites contract will **abort** if the user tries to create a route
that points to a non-existing resource.
```

The simple routing algorithm is as follows:

- Whenever a resource path *is not found among the sites resources*, the Portal tries to match the
  path to the `routes`.
- All matching routes are then *lexicographically ordered*, and the *longest* match is chosen.
- The resource corresponding to this longest match is then served.

```admonish
In other words, the Portal will _always_ serve a resource if present, and if not present will serve
the resource with the _longest matching prefix_ among the routes.
```

Recall the example above:

``` JSON
"routes": {
  "/*": "/index.html",
  "/path/*": "/accounts.html",
  "/path/assets/*": "/assets/asset_router.html"
}
```

The following matchings will occur:

- browsing `/any/other/test.html` will serve `/index.html`;
- browsing `/path/test.html` will serve `/accounts.html`, as it is a more specific match than the
  previous one;
- similarly, browsing `/path/assets/test.html` will serve `/assets/asset_router.html`.

`/index.html`, `/accounts.html`, and `/assets/asset_router.html` are all existing resources on the
Walrus Sites object on Sui.
