# Client Daemon mode & HTTP API

In addition to the CLI and JSON modes, the Walrus client offers a *daemon mode*. In this mode, it
runs a simple web server offering HTTP interfaces to store and read blobs in an *aggregator* and
*publisher* role respectively. We also offer
[public aggregator and publisher services](#public-services) to try the Walrus HTTP APIs without
the need to run a local client.

## Starting the daemon locally {#local-daemon}

You can run the daemon with the following command, to offer both an aggregator and publisher on
the same address (`127.0.0.1`) and port (`31415`):

```sh
walrus daemon -b "127.0.0.1:31415"
```

Or you may run the aggregator and publisher processes separately on different addresses/ports:

```sh
walrus aggregator -b "127.0.0.1:31415" # run an aggregator to read blobs
walrus publisher -b "127.0.0.1:31416" # run a publisher to store blobs
```

The aggregator provides all read APIs, the publisher all the store APIs, and the daemon provides
both.

```admonish warning
While the aggregator does not perform Sui on-chain actions, and therefore consumes no gas, the
publisher does perform actions on-chain and will consume gas. It is therefore important to ensure
only authorized parties may access it, or other measures to manage gas costs.
```

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
- `https://sui-walrus-testnet.bwarelabs.com/aggregator`
- `https://walrus-testnet-aggregator.stakin-nodes.com`
- `https://testnet-aggregator-walrus.kiliglab.io`
- `https://walrus-cache-testnet.latitude-sui.com`
- `https://walrus-tn.juicystake.io:9443`
- `https://walrus-agg-testnet.chainode.tech:9002`
- `https://walrus-testnet-aggregator.starduststaking.com:444`
- `http://walrus-testnet-aggregator.everstake.one:9000`
- `http://walrus.testnet.pops.one:9000`
- `http://scarlet-brussels-376c2.walrus.bdnodes.net:9000`
- `http://aggregator.testnet.sui.rpcpool.com:9000`
- `http://walrus.krates.ai:9000`
- `http://walrus-testnet.stakingdefenseleague.com:9000`
- `http://walrus.sui.thepassivetrust.com:9000`

<!--
Reported but currently not available:
- `https://walrus-testnet-aggregator.nodeinfra.com`
-->

### Public publishers

- `https://publisher.walrus-testnet.walrus.space`
- `https://wal-publisher-testnet.staketab.org`
- `https://walrus-testnet-publisher.bartestnet.com`
- `https://walrus-testnet.blockscope.net:444`
- `https://walrus-testnet-publisher.nodes.guru`
- `https://walrus-publish-testnet.chainode.tech:9003`
- `https://sui-walrus-testnet.bwarelabs.com/publisher`
- `https://walrus-testnet-publisher.stakin-nodes.com`
- `https://testnet-publisher-walrus.kiliglab.io`
- `http://walrus-publisher-testnet.overclock.run:9001`
- `http://walrus-testnet-publisher.everstake.one:9001`
- `http://walrus.testnet.pops.one:9001`
- `http://ivory-dakar-e5812.walrus.bdnodes.net:9001`
- `http://publisher.testnet.sui.rpcpool.com:9001`
- `http://walrus.krates.ai:9001`
- `http://walrus-publisher-testnet.latitude-sui.com:9001`
- `http://walrus-tn.juicystake.io:9090`
- `http://walrus-testnet.stakingdefenseleague.com:9001`
- `http://walrus.sui.thepassivetrust.com:9001`

<!--
Reported but currently not available:
- https://walrus-testnet-publisher.nodeinfra.com
- https://walrus-testnet-aggregator.starduststaking.com:445
-->

## HTTP API Usage

For the following examples, we assume you set the `AGGREGATOR` and `PUBLISHER` environment variables
to your desired aggregator and publisher, respectively. For example:

```sh
AGGREGATOR=https://aggregator.walrus-testnet.walrus.space
PUBLISHER=https://publisher.walrus-testnet.walrus.space
```

```admonish tip title="API specification"
Walrus aggregators and publishers expose their API specifications at the path `/v1/api`. You can
view this in the browser` e.g., at <https://aggregator.walrus-testnet.walrus.space/v1/api>
```

### Store

You can interact with the daemon through simple HTTP PUT requests. For example, with
[cURL](https://curl.se), you can store blobs using a publisher or daemon as follows:

```sh
curl -X PUT "$PUBLISHER/v1/store" -d "some string" # store the string `some string` for 1 storage epoch
curl -X PUT "$PUBLISHER/v1/store?epochs=5" --upload-file "some/file" # store file `some/file` for 5 storage epochs
```

The store HTTP API end points return information about the blob stored in JSON format. When a blob
is stored for the first time, a `newlyCreated` field contains information about the
new blob:

```sh
$ curl -X PUT "$PUBLISHER/v1/store" -d "some other string"
{
  "newlyCreated": {
    "blobObject": {
      "id": "0xd765d11848cbac5b1f6eec2fbeb343d4558cbe8a484a00587f9ef5385d64d235",
      "storedEpoch": 0,
      "blobId": "Cmh2LQEGJwBYfmIC8duzK8FUE2UipCCrshAYjiUheZM",
      "size": 17,
      "erasureCodeType": "RedStuff",
      "certifiedEpoch": 0,
      "storage": {
        "id": "0x28cc75b33e31b3e672646eacf1a7c7a2e5d638644651beddf7ed4c7e21e9cb8e",
        "startEpoch": 0,
        "endEpoch": 1,
        "storageSize": 4747680
      }
    },
    "encodedSize": 4747680,
    "cost": 231850
  }
}
```

The information returned is the content of the [Sui blob object](../dev-guide/sui-struct.md).

When the aggregator finds a certified blob with the same blob ID and a sufficient validity period,
it returns a `alreadyCertified` JSON structure:

```sh
$ curl -X PUT "$PUBLISHER/v1/store" -d "some other string"
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
curl "$AGGREGATOR/v1/<some blob ID>" -o <some file name>
```

Alternatively you may print the contents of a blob in the terminal with the cURL command:

```sh
curl "$AGGREGATOR/v1/<some blob ID>"
```

```admonish tip title="Content sniffing"
Modern browsers will attempt to sniff the content type for such resources, and will generally do a
good job of inferring content types for media. However, the aggregator on purpose prevents such
sniffing from inferring dangerous executable types such as JavaScript or style sheet types.
```
