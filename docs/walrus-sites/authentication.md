# Site data authentication

Walrus Sites offers a simple mechanism to authenticate the data that is served from the Walrus
storage on the client side. Thus, Walrus Sites can guarantee (with various degrees of confidence,
depending on the setup) that the site data is authentic and has not and has not tampered with by a malicious aggregator.

## Authentication mechanism

The Walrus Sites resource object on Sui stores, alongside the resource information, a SHA-256 hash
of the resource's content.

When the client requests a resource, the Portal will check that the hash of the data received from
the Walrus storage (and the Walrus aggregator in particular) matches the hash stored on Sui.

If the hashes do not match, the Portal will return the following warning page:

![Hash mismatch warning page](../assets/walrus-sites-hash-mismatch.png)

## Anthentication Guarantees

Depending on the type of deployment, this technique gives increasing levels of confidence that the
site data is authentic. We list them here in increasing order of assurance.

### Remote server-side Portal deployment

In this case, the user must fully trust the Portal provider to authenticate the data. With a trusted
Portal, the authintication mechanism guarantees that the aggregator or cache (from which the blob
has been fetched) did not tamper with the contents of the blob.

### Remote service-worker Portal deployment

Here, the Portal provider is only trusted to provide the correct service worker code to the user.
The user's browser will then perform the fetching and authentication. The guarantees are therefore
the same as with the remote server-site Portal, with the addition that the user can inspect the code
returned by the Portal provider, and verify its integrity (e.g. by comparing it the hash of the
service worker code to one that is known to be correct).

### Local Portal deployment

Finally, a user can clone the Walrus Sites repository and deploy a Portal locally, browsing Walrus
Sites through `localhost`. In this case, the user has full control over the Portal code and can
verify its operation. Therefore, they can fully authenticate that the data served by Walrus and
Walrus Sites is what the original developer intended.
