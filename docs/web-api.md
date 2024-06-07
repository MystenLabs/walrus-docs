# Client Daemon mode & HTTP API

In addition to the CLI mode, the Walrus client offers a *daemon mode*. In this mode, it runs a
simple web server offering HTTP interfaces to store and read blobs.

## Starting the daemon

You can run the daemon with
different sets of API endpoints through one of the following commands:

```sh
ADDRESS="127.0.0.1:31415" # bind the daemon to localhost and port 31415
walrus -c $CONFIG aggregator -b $ADDRESS # run an aggregator to read blobs
walrus -c $CONFIG publisher -b $ADDRESS # run a publisher to store blobs
walrus -c $CONFIG daemon -b $ADDRESS # run a daemon combining an aggregator and a publisher
```

The aggregator provides all read APIs, the publisher all the store APIs, and daemon provides both.
Note that the aggregator does not perform Sui on-chain actions, and therefore consumes no gas.
However, the publisher does perform actions on-chain and will consume gas. It is therefore important
to ensure only authorized parties may access it, or other measures to manage gas costs.

## HTTP API Usage

You can then interact with the daemon through simple HTTP requests. For example, with
[cURL](https://curl.se), you can store blobs as follows:

```sh
curl -X PUT "http://$ADDRESS/v1/store" -d "some string" # store the string `some string` for 1 storage epoch
curl -X PUT "http://$ADDRESS/v1/store?epochs=5" -d @"some/file" # store file `some/file` for 5 storage epochs
```

Blobs may be read using the following cURL command:

```sh
curl "http://$ADDRESS/v1/<some blob ID>" # read a blob from Walrus (with aggregator or daemon)
```

Modern browsers will attempt to sniff the content type for such resources, and will generally do a
good job of inferring content types for media. However, the aggregator on purpose prevents such
sniffing from inferring dangerous executable types such as javascript or style sheet types.