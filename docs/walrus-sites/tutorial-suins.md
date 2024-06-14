# Bonus: Set a SuiNS name

Browsing a URL like `https://29gjzk8yjl1v7zm2etee1siyzaqfj9jaru5ufs6yyh1yqsgun2.walrus.site` is not
particularly nice. Therefore, Walrus Sites allows to use SuiNS names (this is like DNS for Sui) to
give human-readable names to site. To do so, you simply have to get a SuiNS name you like, and point
it to the object ID of the Walrus Site (as provided by the `publish` or `update` commands).

Let's do this step by step.

## Get a SuiNS name

- Navigate to [https://testnet.suins.io/](https://testnet.suins.io/), and buy a domain name with
  your testnet wallet. For example, `walrusgame` (NOTE: this is already taken, choose another you
  like!). NOTE: At the moment, you can only select names that are composed of letters `a-z` and
  numbers `0-9`, but no special characters (e.g., `-`).
- In the [page](https://testnet.suins.io/account/my-names) listing the domains you own, you should
  see the newly-bought name.
- Click the three-dots menu on the top-right corner of the name you want to assign. Choose "View all
  info", and copy the `ObjectID`. In our case, this is
  `0x6412c4cfbe50e219c2d4d30108d7321d064e15bf64e752307100bff5eb91da38`.

## Send the SuiNS registration object to the address you use with the Sui CLI

The steps that follow require that the SuiNS registration object is owned by the address you are
using on the Sui CLI. Therefore, we need to send this registration object from the address you use
in your browser wallet, to the address of your Sui CLI.

To find the Sui CLI address, execute:

``` sh
sui client active-address
```

Then, from your browser wallet, select the "Assets" tab, and look for the NFT of the SuiNS
registration, which should look as follows:

![the SuiNS registration inside the wallet](../assets/suins-asset.png)

Click on it, scroll down to "Send NFT", and send it to the address discovered with the command
above. Now, your Sui CLI address owns the registration NFT, and you can proceed to the next step.

## Map the SuiNS name to the Walrus Site

This step associates the name `walrusgame` to the object ID of our Walrus Site. There are possibly
many ways to achieve this, and as the SuiNS UI improves this could be done from the webapp as well.

Here, we issue an transaction using the Sui CLI that creates this mapping:

```sh
SUINS_CORE_PACKAGE=0x22fa05f21b1ad71442491220bb9338f7b7095fe35000ef88d5400d28523bdd93
SUINS_CORE_OBJECT=0x300369e8909b9a6464da265b9a5a9ab6fe2158a040e84e808628cde7a07ee5a3
MY_SUINS_REGISTRATION_OBJECT=0x6412... # adjust this to your own SuiNS object
MY_WALRUS_SITE_OBJECT=0x5ac9... # adjust this to your Walrus Site object
sui client call \
    --package $SUINS_CORE_PACKAGE \
    --module controller \
    --function set_target_address \
    --gas-budget 500000000 \
    --args $SUINS_CORE_OBJECT \
    --args $MY_SUINS_REGISTRATION_OBJECT \
    --args "[$MY_WALRUS_SITE_OBJECT]" \
    --args 0x6
```

Note that SuiNS package and object on testnet may change, you can find the latest ones in the [SuiNS
documentation](https://docs.suins.io/#active-constants) (make sure you select _Testnet_).

If all succeeds, we can now browse [https://walrusgame.walrus.site](https://walrusgame.walrus.site)!
