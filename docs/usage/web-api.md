# Client Daemon mode & HTTP API

In addition to the CLI and JSON modes, the Walrus client offers a *daemon mode*. In this mode, it
runs a simple web server offering HTTP interfaces to store and read blobs in an aggregator and
publisher role respectively. We also offer
[public aggregator and publisher services](#public-services) to try the Walrus HTTP APIs without
the need to run a local client.

## Starting the daemon locally

You can run the daemon with the following command, to offer both an aggregator and publisher on
the same address and port:

```sh
ADDRESS="127.0.0.1:31415" # bind the daemon to localhost and port 31415 for both
walrus daemon -b $ADDRESS # run a daemon combining an aggregator and a publisher
```

Or you may run two separate processes. One for the aggregator:

```sh
AGG_ADDRESS="127.0.0.1:31415" # Aggregator only port
walrus aggregator -b $AGG_ADDRESS # run an aggregator to read blobs
```

And a different one for the publisher:

```sh
PUB_ADDRESS="127.0.0.1:31416" # Note different port for publisher
walrus publisher -b $PUB_ADDRESS # run a publisher to store blobs
```

The aggregator provides all read APIs, the publisher all the store APIs, and the daemon provides
both. Note that the aggregator does not perform Sui on-chain actions, and therefore consumes no gas.
However, the publisher does perform actions on-chain and will consume gas. It is therefore important
to ensure only authorized parties may access it, or other measures to manage gas costs.

## Using a public aggregator or publisher {#public-services}

For some use cases (e.g., a public website), or to just try out the HTTP API, a publicly accessible
aggregator and/or publisher is required. For your convenience, we provide these at the following
hosts:

- Aggregator: `http://sea-dnt-sto-00.devnet.sui.io:9000`
- Publisher: `http://ord-dnt-sto-00.devnet.sui.io:9000`

Note that the publisher consumes (testnet) Sui on the service side, and a mainnet deployment would
likely not be able to provide uncontrolled public access to publishing without requiring some
authentication and compensation for the Sui used.

## HTTP API Usage

### Store

You can interact with the daemon through simple HTTP PUT requests. For example, with
[cURL](https://curl.se), you can store blobs using a publisher or daemon as follows:

```sh
ADDRESS="127.0.0.1:31415"
curl -X PUT "http://$ADDRESS/v1/store" -d "some string" # store the string `some string` for 1 storage epoch
curl -X PUT "http://$ADDRESS/v1/store?epochs=5" --upload-file "some/file" # store file `some/file` for 5 storage epochs
```

The store HTTP API end points return information about the blob stored in JSON format. When a blob
is stored for the first time, a `newlyCreated` field contains information about the
new blob:

```
$ curl -X PUT "http://ord-dnt-sto-00.devnet.sui.io:9000/v1/store" -d "some other string"
{
  "newlyCreated":{
    "id":"0xa74d376bb6923c4b8d73825fce3b798524e2bda34d02dae64ab5865556c54000",
    "storedEpoch":0,
    "blobId":"gsYzDXsK326Wihzt3X5evZCPFgaNZrb84zCjodLJaVs",
    "size":36,
    "erasureCodeType":"RedStuff",
    "certified":0,
    "storage":{
        "id":"0x2479b3096efa58fa9bfbebe805268746c235110ee0713e5a123d8f1754c2ccc3",
        "startEpoch":0,
        "endEpoch":1,
        "storageSize":4747680
    }
  }
}
```
The information returned is the content of the [Sui blob object](../dev-guide/sui-struct.md).

When the aggregator finds a blob with the same blob ID it returns a `alreadyCertified` JSON
structure:
```
$ curl -X PUT "http://ord-dnt-sto-00.devnet.sui.io:9000/v1/store" -d "some other string"
{
  "alreadyCertified":{
    "blobId":"gsYzDXsK326Wihzt3X5evZCPFgaNZrb84zCjodLJaVs",
    "event":{
      "txDigest":"2oMC1dTaMGpApphFWKzARSsTM9837ox4zN8rY2RqLf6c",
      "eventSeq":"0"
    },
    "endEpoch":1
  }
}
```
The field `event` returns the [Sui event ID](../dev-guide/sui-struct.md) that can be used to
find the transaction that created the Sui Blob object on the Sui explorer or using a Sui SDK.

### Read

Blobs may be read from an aggregator or daemon using HTTP GET. For example the following cURL
command, reads a blob and writes it to an output file:

```sh
ADDRESS="127.0.0.1:31415"
curl "http://$ADDRESS/v1/<some blob ID> -o <some file name>"
```

Alternatively you may print the contents of a blob in the terminal with the cURL command:

```sh
ADDRESS="127.0.0.1:31415"
curl "http://$ADDRESS/v1/<some blob ID>
```

Modern browsers will attempt to sniff the content type for such resources, and will generally do a
good job of inferring content types for media. However, the aggregator on purpose prevents such
sniffing from inferring dangerous executable types such as javascript or style sheet types.
