# Redirecting objects to Walrus Sites

We have seen in the [overview](./overview.md) how a Walrus Site object on Sui looks like. We will
discuss now how you can create ensure that a *set of arbitrary objects* can all be tied to a
specific, and possibly unique, Walrus Site.

## The goal

Consider a collection of NFTs, such as the one published by <https://flatland.walrus.site>. As we
show there, each minted NFT has its own Walrus Site, which can be personalized based on the contents
(e.g., the color) of the NFT itself. How can we achieve this?

## Redirect links

The solution is simple: We add a "redirect" in the NFT's
[`Display`](https://docs.sui.io/standards/display#sui-utility-objects) property. Each time an NFT's
object ID is browsed through a Portal, the Portal will check the `Display` of the NFT and, if it
encounters the `walrus site address` key, it will go fetch the Walrus Site that is at the
corresponding object ID.

### Redirects in Move

Practically speaking, when creating the `Display` of the NFT, you can include the key-value pair
that points to the Walrus Site that is to be used.

``` move
...
const VISUALIZATION_SITE: address = @0x901fb0...;
display.add(b"walrus site address".to_string(), VISUALIZATION_SITE.to_string());
...
```

### How to personalize based on the NFT?

The code above will only open the specified Walrus Site when browsing the object ID of the NFT. How
do we ensure that the properties of the NFT can be used to personalize the site?

This needs to be done in the `VISUALIZATION_SITE`: Since the subdomain is still pointing to the
NFT's object ID, the Walrus Site that is loaded can check its `origin` in JavaScript, and use the
subdomain to determine the NFT, fetch it from chain, and use its internal fields to modify the
displayed site.
