# Introduction to Walrus Sites

*Walrus Sites* are "web"-sites that use Sui and Walrus as their underlying technology. They are a
prime example of how Walrus can be used to build new and exciting decentralized applications. Anyone
can build and deploy a Walrus Site and make it accessible to the world! Funnily, this documentation
is itself available as a Walrus Site at <https://docs.walrus.site/walrus-sites/intro.html> (if you
aren't there already).

At a high level, here are some of the most exciting features:

- Publishing a site does not require managing servers or complex configurations; just provide the
  source files (produced by your favorite web framework), publish them to Walrus Sites using the
  [site-builder tool](./overview.md#the-site-builder), and you are done!
- Sites can be linked to from ordinary Sui objects. This feature enables, for example, creating an
  NFT collection in which *every single NFT* has a *personalized website dedicated to it*.
- Walrus Sites are owned by addresses on Sui and can be exchanged, shared, and updated thanks to
  Sui's flexible programming model. This means, among other things, that Walrus Sites can leverage
  the [SuiNS](https://suins.io/) naming system to have human-readable names. No more messing around
  with DNS!
- Thanks to Walrus's decentralization and extremely high data availability, there is no risk of
  having your site wiped for no reason.
- Since they live on Walrus, these sites cannot have a backend in the traditional sense, and can be
  therefore considered "static" sites. However, the developer can integrate with Sui-compatible
  wallets and harness Sui's programmability to add backend functionality to Walrus Sites!

## Show me

To give you a very high-level intuition of how Walrus Sites work, let's look at an example: A simple
NFT collection on Sui that has a frontend dApp to mint the NFTs hosted on Walrus Sites, and in
which *each NFT* has a *specific, personalized Walrus Site*.

You can check out the mint page at <https://flatland.walrus.site/>. This site is served to your
browser through the Walrus Site *Portal* <https://walrus.site>. While the Portal's operation is
explained in a [later section](./portal.md), consider for now that there can be many Portals (hosted
by whoever wants to have their own, and even on `localhost`). Further, the only function of the
Portal is to provide the browser with some code (specifically, a service worker) that allows it to
fetch the Walrus Site from Sui and Walrus.

If you have a Sui wallet with some Testnet SUI, you can try and "mint a new Flatlander" from the
site. This creates an NFT from the collection and shows you two links: one to the explorer, and one
to the "Flatlander site". This latter site is a special Walrus Site that exists only for that NFT,
and has special characteristics (the background color, the image, ...) that are based on the
contents of the NFT.

The URL to this per-NFT site looks something like this:
`https://4egmmrw9izzjn0dm2lkd3k0l8phk386z60ub1tpdc1jswbb5dr.walrus.site/`. You'll notice that the
domain remains `walrus.site`, but the subdomain is a long and random-looking string. This string is
actually the [Base36](https://en.wikipedia.org/wiki/Base36) encoding of the object ID of the NFT,
which is
[0xb09b312b...](https://suiscan.xyz/testnet/object/0xb09b312b28049467dd6173b6cebb60ed5fe3046883e248632bf9fb20b7dbdaff).

In summary:

- Walrus Sites are served through a Portal; in this case, `https://walrus.site`. There can be many
  Portals, and anyone can host one.
- The subdomain on the URL points to a specific object on Sui that allows the browser to fetch and
  render the site resources. This pointer can be
  - a SuiNS name, such as `flatland` in `https://flatland.walrus.site`, or
  - the Base36 encoding of a the Sui object ID, such as `0xb09b312b...` in the example above.

Curious to know how this magic is possible? Read the [technical overview](./overview.md)! If you
just want to get started trying Walrus Sites out, check the [tutorial](./tutorial.md).
