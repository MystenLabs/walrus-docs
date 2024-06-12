# Bonus: Set a SuiNS name

Browsing a URL like `https://29gjzk8yjl1v7zm2etee1siyzaqfj9jaru5ufs6yyh1yqsgun2.walrus.site` is not
particularly nice. Therefore, Walrus Sites allows to use SuiNS names (this is like DNS for Sui) to
give human-readable names to site. To do so, you simply have to get a SuiNS name you like, and point
it to the object ID of the Walrus Site (as provided by the `publish` or `update` commands).

Let's do this step by step.

## Get a SuiNS name

IMPORTANT: for this to work, the wallet with which you purchase the SuiNS name should be the same as
the wallet you use in the Sui CLI. Unfortunately the SuiNS interface on Testnet does not allow
setting the resolution through the UI.

- Navigate to [https://testnet.suins.io/](https://testnet.suins.io/), and buy a domain name with
  your testnet wallet. For example, `walrusgame` (NOTE: this is already taken, choose another you
  like!). NOTE: At the moment, you can only select names that are composed of letters `a-z` and
  numbers `0-9`, but no special characters (e.g., `-`).
- In the [page](https://testnet.suins.io/account/my-names) listing the domains you own, you should
  see the newly-bought name.
- Click the three-dots menu on the top-right corner of the name you want to assign. Choose "View all
  info", and copy the `ObjectID`. In our case, this is
  `0x6412c4cfbe50e219c2d4d30108d7321d064e15bf64e752307100bff5eb91da38`.

## Map the SuiNS name to the Walrus Site

This step associates the name `walrusgame` to the object ID of our Walrus Site. There are possibly
many ways to achieve this, and as the SuiNS UI improves this could be done from the webapp as well.

Here, we issue an transaction using the Sui CLI that creates this mapping.

``` sh
 sui client call \
    --package 0x22fa05f21b1ad71442491220bb9338f7b7095fe35000ef88d5400d28523bdd93 \
    --module controller \
    --function set_target_address \
    --gas-budget 500000000 \
    --args 0x300369e8909b9a6464da265b9a5a9ab6fe2158a040e84e808628cde7a07ee5a3 \
    --args 0x6412c4cfbe50e219c2d4d30108d7321d064e15bf64e752307100bff5eb91da38 \
    --args "[0x5ac988828a0c9842d91e6d5bdd9552ec9fcdddf11c56bf82dff6d5566685a31e]" \
    --args 0x6
```

If all succeeds, we can now browse [https://walrusgame.walrus.site](https://walrusgame.walrus.site)!
