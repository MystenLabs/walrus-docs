# Known restrictions

Walrus Sites can be used to deploy almost any form of traditional static "Web 2" website build for
modern browsers. There are, however, a number of restrictions that a developer should keep in mind
when creating or porting a website to Walrus Sites.

## No secret values

Walrus Sites are fully publicly accessible, as the metadata is stored on Sui and the site content is
stored on Walrus. Therefore, developers _must_ not store secret values within the sites.

We emphasize again that any such backend-specific operations (storing secret values, authentication,
etc.) are achievable by leveraging the integration with the Sui blockchain and a Sui-compatible
wallet.

## There is a maximum redirect depth

The number of consecutive redirects a Walrus Site can perform is capped by the
Portal (see [Portal configuration](./portal.md)).  This measure ensures that loading a Walrus Site
does not result in an infinite loading loop.

Different Portals can set this limit as they desire. The limit for the Portal hosted at
[walrus.site](http://walrus.site) has a maximum redirect depth of 3.

## Service workers are not available

**WARNING**: This limitation only applies to Portal based on service workers. A web Portal will not
have this limitation.

Walrus Sites leverage service workers in the clients' browsers to perform these essential
operations:

1. reading the site metadata from Sui;
1. fetching the page content from Walrus; and
1. serving the content to the browser.

Therefore, a site deployed on Walrus Sites cannot use service workers. Installing a service worker
from within a Walrus Site will result in a dysfunctional site and a poor experience for the user.

## iOS Sui Mobile Wallets do not work with Walrus Sites

**WARNING**: This limitation only applies to Portal based on service workers. A web Portal will not
have this limitation.

Service workers cannot be loaded inside an in-app browser on iOS, because of a limitation of the
WebKit engine. As a consequence, Walrus Sites cannot be used within Sui-compatible wallet apps on
iOS. Therefore, Sui wallets cannot currently be used on a Walrus Site on iOS. Note, however, that
_browsing_ a Walrus Site is still possible on iOS through any browser. Only the connection to the
wallet is impacted.

The connection with the Sui Wallet apps works on Android devices.
