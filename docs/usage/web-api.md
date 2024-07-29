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
aggregator and/or publisher is required. For your convenience, we provide these at the following
hosts:

- Aggregator: `https://aggregator-devnet.walrus.space`
- Publisher: `https://publisher-devnet.walrus.space`

Our publisher is currently limiting requests to 10 MiB. If you want to upload larger files, you need
to [run your own publisher](#local-daemon) or use the [CLI](./client-cli.md).

Note that the publisher consumes (Testnet) Sui on the service side, and a Mainnet deployment would
likely not be able to provide uncontrolled public access to publishing without requiring some
authentication and compensation for the Sui used.

## HTTP API Usage

For the following examples, we assume you set the `AGGREGATOR` and `PUBLISHER` environment variables
to your desired aggregator and publisher, respectively. For example:

```sh
AGGREGATOR=https://aggregator-devnet.walrus.space
PUBLISHER=https://publisher-devnet.walrus.space
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
curl "$AGGREGATOR/v1/<some blob ID> -o <some file name>"
```

Alternatively you may print the contents of a blob in the terminal with the cURL command:

```sh
curl "$AGGREGATOR/v1/<some blob ID>
```

```admonish tip title="Content sniffing"
Modern browsers will attempt to sniff the content type for such resources, and will generally do a
good job of inferring content types for media. However, the aggregator on purpose prevents such
sniffing from inferring dangerous executable types such as JavaScript or style sheet types.
```
