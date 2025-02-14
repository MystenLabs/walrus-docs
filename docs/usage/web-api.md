# Client Daemon mode & HTTP API

In addition to the CLI and JSON modes, the Walrus client offers a *daemon mode*. In this mode, it
runs a simple web server offering HTTP interfaces to store and read blobs in an *aggregator* and
*publisher* role respectively. We also offer
[public aggregator and publisher services](#public-services) to try the Walrus HTTP APIs without
the need to run a local client.

## Starting the daemon locally {#local-daemon}

You can run a local Walrus daemon through the `walrus` binary. There are three different commands:

- `walrus aggregator` starts an "aggregator" that offers an HTTP interface to read blobs from
  Walrus.
- `walrus publisher` starts a "publisher" that offers an HTTP interface to store blobs in Walrus.
- `walrus daemon` offers the combined functionality of an aggregator and publisher on the same
  address and port.

The aggregator does not perform any on-chain actions, and only requires specifying the address on
which it listens:

```sh
walrus aggregator --bind-address "127.0.0.1:31415"
```

The publisher and daemon perform on-chain actions and thus require a Sui Testnet wallet with
sufficient SUI and WAL balances. To enable handling many parallel requests without object
conflicts, they create internal sub-wallets since version 1.4.0, which are funded from the main
wallet. These sub-wallets are persisted in a directory specified with the `--sub-wallets-dir`
argument; any existing directory can be used. If it already contains sub-wallets, they will be
reused.

By default, 8 sub-wallets are created and funded. This can be changed with the `--n-clients`
argument. For simple local testing, 1 or 2 sub-wallets are usually sufficient.

For example, you can run a publisher with a single sub-wallet stored in the Walrus configuration
directory with the following command:

```sh
PUBLISHER_WALLETS_DIR=~/.config/walrus/publisher-wallets
mkdir -p "$PUBLISHER_WALLETS_DIR"
walrus publisher \
  --bind-address "127.0.0.1:31416" \
  --sub-wallets-dir "$PUBLISHER_WALLETS_DIR" \
  --n-clients 1
```

Replace `publisher` by `daemon` to run both an aggregator and publisher on the same address and
port.

```admonish warning
While the aggregator does not perform Sui on-chain actions, and therefore consumes no gas, the
publisher does perform actions on-chain and will consume both SUI and WAL tokens. It is therefore
important to ensure only authorized parties may access it, or other measures to manage gas costs,
especially in a future Mainnet deployment.
```

### Notes on publisher operation

We list here a few important details on how the publisher deals with funds and objects on Sui.

#### Number of sub-wallets

As mentioned above, the publisher uses sub-wallets to allow storing blobs in parallel. By default,
the publisher uses 8 sub-wallets, meaning it can store 8 blobs at the same time.

#### Funds in sub-wallets

Each of the sub-wallets requires funds to interact with the chain and purchase storage. For this
reason, a background process checks periodically if the sub-wallets have enough funds. In steady
state, each of the sub-wallets will have a balance of 0.5-1.0 SUI and WAL. The amount and triggers
for coin refills can be configured through CLI arguments.

#### Lifecycle of created `Blob` objects

Each store operation in Walrus creates a `Blob` object on Sui. This blob object represents the
(partial) ownership over the associated data, and allows certain data management operations (e.g.,
in the case of deletable blobs).

When the publisher stores a blob on behalf of a client, the `Blob` object is initially owned by the
sub-wallet that stored the blob. Then, the following cases are possible, depending on the
configuration:

- If the client requests to store a blob and specifies the `send_object_to` query parameter (see
  [the relevant section](#store) for examples), then the `Blob` object is transferred to the
  specified address. This is a way for clients to get back the created object for their data.
- If the `send_object_to` query parameter is not specified, two cases are possible:
  - If the publisher was run with the `--keep` flag, then the sub-wallet transfers the
    newly-created blob object to the main wallet, such that all these objects are kept there.
  - If the `--keep` flag was omitted, then the sub-wallet *immediately burns* the `Blob` object.
    Since no one has requested the object, and the availability of the data on Walrus is independent
    of the existence of such object, it is safe to do so. This is to avoid cluttering the sub-wallet
    with many blob objects.

## Using a public aggregator or publisher {#public-services}

For some use cases (e.g., a public website), or to just try out the HTTP API, a publicly accessible
aggregator and/or publisher is required. Several entities run such aggregators and publishers, see
the lists of public [aggregators](#public-aggregators) and [publishers](#public-publishers) below.

Public publishers limit requests to 10 MiB by default. If you want to upload larger files, you need
to [run your own publisher](#local-daemon) or use the [CLI](./client-cli.md).

Also, note that the publisher consumes (Testnet) SUI and WAL on the service side, and a Mainnet
deployment would likely not be able to provide uncontrolled public access to publishing without
requiring some authentication and compensation for the funds used.

### Public aggregators

The following is a list of know public aggregators; they are checked periodically, but each of them
may still be temporarily unavailable:

- `https://aggregator.walrus-testnet.walrus.space`
- `https://wal-aggregator-testnet.staketab.org`
- `https://walrus-testnet-aggregator.bartestnet.com`
- `https://walrus-testnet.blockscope.net`
- `https://walrus-testnet-aggregator.nodes.guru`
- `https://walrus-cache-testnet.overclock.run`
- `https://walrus-testnet-aggregator.stakin-nodes.com`
- `https://testnet-aggregator-walrus.kiliglab.io`
- `https://walrus-cache-testnet.latitude-sui.com`
- `https://walrus-testnet-aggregator.nodeinfra.com`
- `https://walrus-testnet-aggregator.stakingdefenseleague.com`
- `https://walrus-aggregator.rubynodes.io`
- `https://walrus-testnet-aggregator.brightlystake.com`
- `https://walrus-testnet-aggregator.nami.cloud`
- `https://aggregator.testnet.walrus.mirai.cloud`
- `https://walrus-testnet-aggregator.stakecraft.com`
- `https://agg.test.walrus.eosusa.io`
- `https://walrus-agg.testnet.obelisk.sh`
- `https://walrus-test-aggregator.thepassivetrust.com`
- `https://walrus-testnet-aggregator.natsai.xyz`
- `https://walrus.testnet.aggregator.stakepool.dev.br`
- `https://aggregator.walrus.banansen.dev`
- `https://aggregator.walrus.silentvalidator.com`
- `https://testnet-aggregator.walrus.graphyte.dev`
- `https://walrus-testnet-aggregator.imperator.co`
- `https://walrus-testnet-aggregator.unemployedstake.co.uk`
- `https://aggregator.walrus-01.tududes.com`
- `https://walrus-aggregator.n1stake.com`
- `https://suiftly-testnet-agg.mhax.io`
- `https://walrus-testnet-aggregator.trusted-point.com`
- `https://walrus-testnet-aggregator.veera.com`
- `https://aggregator.testnet.walrus.atalma.io`
- `https://153-gb3-val-walrus-aggregator.stakesquid.com`
- `https://sui-walrus-testnet.bwarelabs.com/aggregator`
- `https://walrus-testnet.chainbase.online/aggregator`
- `https://walrus-tn.juicystake.io:9443`
- `https://walrus-agg-testnet.chainode.tech:9002`
- `https://walrus-testnet-aggregator.starduststaking.com:11444`
- `https://walrus-aggregator-testnet.cetus.zone`
- `http://walrus-testnet-aggregator.everstake.one:9000`
- `http://walrus.testnet.pops.one:9000`
- `http://scarlet-brussels-376c2.walrus.bdnodes.net:9000`
- `http://aggregator.testnet.sui.rpcpool.com:9000`
- `http://walrus.krates.ai:9000`
- `http://walrus.globalstake.io:9000`
- `http://walrus-testnet.staking4all.org:9000`
- `http://walrus-testnet.rpc101.org:9000`
- `http://93.115.27.108:9000`
- `http://65.21.139.112:9000`
- `http://162.19.18.19:9000`
- `http://walrus-aggregator.stakeme.pro:9000`
- `http://walrus-storage.testnet.nelrann.org:9000`
- `http://walrus-testnet.equinoxdao.xyz:9000`
- `https://walrus-testnet-aggregator.stakely.io`
- `- `walrus-testnet-aggregator.criterionvc.com``

### Public publishers

- `https://publisher.walrus-testnet.walrus.space`
- `https://wal-publisher-testnet.staketab.org`
- `https://walrus-testnet-publisher.bartestnet.com`
- `https://walrus-testnet-publisher.nodes.guru`
- `https://walrus-testnet-publisher.stakin-nodes.com`
- `https://testnet-publisher-walrus.kiliglab.io`
- `https://walrus-testnet-publisher.nodeinfra.com`
- `https://walrus-publisher.rubynodes.io`
- `https://walrus-testnet-publisher.brightlystake.com`
- `https://walrus-testnet-publisher.nami.cloud`
- `https://publisher.testnet.walrus.mirai.cloud`
- `https://walrus-testnet-publisher.stakecraft.com`
- `https://pub.test.walrus.eosusa.io`
- `https://walrus-pub.testnet.obelisk.sh`
- `https://walrus-testnet-publisher.stakingdefenseleague.com`
- `https://walrus-testnet.thepassivetrust.com`
- `https://walrus-testnet-publisher.natsai.xyz`
- `https://walrus.testnet.publisher.stakepool.dev.br`
- `https://publisher.walrus.banansen.dev`
- `https://publisher.walrus.silentvalidator.com`
- `https://testnet-publisher.walrus.graphyte.dev`
- `https://walrus-testnet-publisher.imperator.co`
- `https://walrus-testnet-publisher.unemployedstake.co.uk`
- `https://publisher.walrus-01.tududes.com`
- `https://walrus-publisher.n1stake.com`
- `https://suiftly-testnet-pub.mhax.io`
- `https://walrus-testnet-publisher.trusted-point.com`
- `https://walrus-testnet-publisher.veera.com`
- `https://publisher.testnet.walrus.atalma.io`
- `https://153-gb3-val-walrus-publisher.stakesquid.com`
- `https://sui-walrus-testnet.bwarelabs.com/publisher`
- `https://walrus-testnet.chainbase.online/publisher`
- `https://walrus-testnet.blockscope.net:11444`
- `https://walrus-publish-testnet.chainode.tech:9003`
- `https://walrus-testnet-publisher.starduststaking.com:11445`
- `http://walrus-publisher-testnet.overclock.run:9001`
- `http://walrus-testnet-publisher.everstake.one:9001`
- `http://walrus.testnet.pops.one:9001`
- `http://ivory-dakar-e5812.walrus.bdnodes.net:9001`
- `http://publisher.testnet.sui.rpcpool.com:9001`
- `http://walrus.krates.ai:9001`
- `http://walrus-publisher-testnet.latitude-sui.com:9001`
- `http://walrus-tn.juicystake.io:9090`
- `http://walrus.globalstake.io:9001`
- `http://walrus-testnet.staking4all.org:9001`
- `http://walrus-testnet.rpc101.org:9001`
- `http://walrus-publisher-testnet.cetus.zone:9001`
- `http://93.115.27.108:9001`
- `http://65.21.139.112:9001`
- `http://162.19.18.19:9001`
- `http://walrus-publisher.stakeme.pro:9001`
- `http://walrus-storage.testnet.nelrann.org:9001`
- `http://walrus-testnet.equinoxdao.xyz:9001`
- `https://walrus-testnet-publisher.stakely.io`
- `walrus-testnet-publisher.criterionvc.com`

## HTTP API Usage

For the following examples, we assume you set the `AGGREGATOR` and `PUBLISHER` environment variables
to your desired aggregator and publisher, respectively. For example:

```sh
AGGREGATOR=https://aggregator.walrus-testnet.walrus.space
PUBLISHER=https://publisher.walrus-testnet.walrus.space
```

```admonish tip title="API specification"
Walrus aggregators and publishers expose their API specifications at the path `/v1/api`. You can
view this in the browser, for example, at <https://aggregator.walrus-testnet.walrus.space/v1/api>.
```

### Store

You can interact with the daemon through simple HTTP PUT requests. For example, with
[cURL](https://curl.se), you can store blobs using a publisher or daemon as follows:

```sh
curl -X PUT "$PUBLISHER/v1/blobs" -d "some string" # store the string `some string` for 1 storage epoch
curl -X PUT "$PUBLISHER/v1/blobs?epochs=5" --upload-file "some/file" # store file `some/file` for 5 storage epochs
curl -X PUT "$PUBLISHER/v1/blobs?send_object_to=$ADDRESS" --upload-file "some/file" # store file `some/file` and send the blob object to $ADDRESS
curl -X PUT "$PUBLISHER/v1/blobs?deletable=true" --upload-file "some/file" # store file `some/file` as a deletable blob, instead of a permanent one
```

The store HTTP API end points return information about the blob stored in JSON format. When a blob
is stored for the first time, a `newlyCreated` field contains information about the
new blob:

```sh
$ curl -X PUT "$PUBLISHER/v1/blobs" -d "some other string"
{
  "newlyCreated": {
    "blobObject": {
      "id": "0xd765d11848cbac5b1f6eec2fbeb343d4558cbe8a484a00587f9ef5385d64d235",
      "registeredEpoch": 0,
      "blobId": "Cmh2LQEGJwBYfmIC8duzK8FUE2UipCCrshAYjiUheZM",
      "size": 17,
      "encodingType": "RedStuff",
      "certifiedEpoch": 0,
      "storage": {
        "id": "0x28cc75b33e31b3e672646eacf1a7c7a2e5d638644651beddf7ed4c7e21e9cb8e",
        "startEpoch": 0,
        "endEpoch": 1,
        "storageSize": 4747680
      },
      "deletable": false
    },
    "resourceOperation": {
      "registerFromScratch": {
        "encodedLength": 4747680,
        "epochsAhead": 1
      }
    },
    "cost": 231850
  }
}
```

The information returned is the content of the [Sui blob object](../dev-guide/sui-struct.md).

When the aggregator finds a certified blob with the same blob ID and a sufficient validity period,
it returns a `alreadyCertified` JSON structure:

```sh
$ curl -X PUT "$PUBLISHER/v1/blobs" -d "some other string"
{
  "alreadyCertified": {
    "blobId": "Cmh2LQEGJwBYfmIC8duzK8FUE2UipCCrshAYjiUheZM",
    "event": {
      "txDigest": "CLE41JTPR2CgZRC1gyKK6P3xpQRHCetQMsmtEgqGjwst",
      "eventSeq": "0"
    },
    "endEpoch": 1
  }
}
```

The field `event` returns the [Sui event ID](../dev-guide/sui-struct.md) that can be used to
find the transaction that created the Sui Blob object on the Sui explorer or using a Sui SDK.

### Read

Blobs may be read from an aggregator or daemon using HTTP GET. For example, the following cURL
command reads a blob and writes it to an output file:

```sh
curl "$AGGREGATOR/v1/blobs/<some blob ID>" -o <some file name>
```

Alternatively you may print the contents of a blob in the terminal with the cURL command:

```sh
curl "$AGGREGATOR/v1/blobs/<some blob ID>"
```

```admonish tip title="Content sniffing"
Modern browsers will attempt to sniff the content type for such resources, and will generally do a
good job of inferring content types for media. However, the aggregator on purpose prevents such
sniffing from inferring dangerous executable types such as JavaScript or style sheet types.
```
