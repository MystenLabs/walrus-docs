# Bonus: Set a SuiNS name

Browsing a URL like `https://1lupgq2auevjruy7hs9z7tskqwjp5cc8c5ebhci4v57qyl4piy.walrus.site` is not
particularly nice. Therefore, Walrus Sites allows to use SuiNS names (this is like DNS for Sui) to
assign a human-readable name to a Walrus Site. To do so, you simply have to get a SuiNS name you
like, and point it to the object ID of the Walrus Site (as provided by the `publish` or `update`
commands).

Let's do this step by step.

## Get a SuiNS name

- Navigate to <https://testnet.suins.io> and buy a domain name with your Testnet wallet. For
  example, `walrusgame` (this specific one is already taken, choose another you like).

  ```admonish note
  At the moment, you can only select names that are composed of letters `a-z` and numbers `0-9`, but
  no special characters (e.g., `-`).
  ```

## Map the SuiNS name to the Walrus Site

Now, you can set the SuiNS name to point to the address of your Walrus Site. To do so, go to the
["names you own"](https://testnet.suins.io/account/my-names) section of the SuiNS website, click on
the "three dots" menu icon above the name you want to map, and click "Link To Wallet Address". Paste
in the bar the object ID of the Walrus Site, check that it is correct, and click "Apply".

After approving the transaction, we can now browse <https://walrusgame.walrus.site>!
