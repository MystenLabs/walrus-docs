# Components

From a developer perspective, some Walrus components are objects and smart contracts on
Sui, and some components are Walrus-specific binaries and services. As a rule, Sui is used to
manage blob and storage node metadata, while Walrus-specific services are used to store and
read blob contents, which can be very large.

Walrus defines a number of objects and smart contracts on Sui:

- A shared *system object* records and manages the current committee of storage nodes.
- *Storage resources* represent empty storage space that may be used to store blobs.
- *Blob resources* represent blobs being registered and certified as stored.
- Changes to these objects emit *Walrus-related events*.

The Walrus system object ID can be found in the Walrus `client_config.yaml` file (see
[Configuration](../usage/setup.md#configuration)). You may use any Sui explorer to look at its
content, as well as explore the content of blob objects. There is more information about these in
the [quick reference to the Walrus Sui structures](sui-struct.md).

Walrus is also composed of a number of Walrus-specific services and binaries:

- A client (binary) can be executed locally and provides a
  [Command Line Interface (CLI)](../usage/client-cli.md), a [JSON API](../usage/json-api.md)
  and an [HTTP API](../usage/web-api.md) to perform Walrus operations.
- Aggregator services allow reading blobs via HTTP requests.
- Publisher services are used store blobs to Walrus.
- A set of storage nodes store encoded blobs. These nodes form the decentralized
  storage infrastructure of Walrus.

Aggregators, publishers, and other services use the client APIs to interact with Walrus. End users
of services using Walrus interact with the store via custom services, aggregators, or publishers
that expose HTTP APIs to avoid the need to run locally a binary client.
