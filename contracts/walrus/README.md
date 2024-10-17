# Walrus Testnet Move contracts

This is the Move source code for the Walrus Testnet instance. We provide this so developers can
experiment with building Walrus apps that require Move extensions. These contracts are deployed on
Sui Testnet as package `0x9f992cc2430a1f442ca7a5ca7638169f5d5c00e0ebc3977a65e9ac6e497fe5ef`.

**A word of caution:** Walrus Mainnet will use new Move packages with struct layouts and function
signatures that may not be compatible with this package. Move code that builds against this package
will need to adapted.
