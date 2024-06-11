# Components

From a developer perspective Walrus has some components that are objects and smart contracts on
Sui, and some components that are an independent set of services. As a rule Sui is used to manage
blob and storage node metadata, while off-sui components are used to actually store and read blob
data, which can be large.

Walrus defines a number of objects and smart contracts on Sui:

- A shared *system object*, records and manages the current committee of storage nodes.
- *Storage resources*, represent empty storage space that may be used to store blobs.
- *Blob resources*, represent blobs being registered and certified as stored.

The system object ID for Walrus can be found in the Walrus `client_config.yaml` file. You may use
any Sui explorer to look at its content, as well as explore the content of blob objects. You can
find more information in the [quick reference to the Walrus Sui structures](sui-struct.md).

Walrus is also composed of a number of services and binaries:

- A client (binary) can be executed locally and provides a
  [Command Line Interface (CLI)](client-cli.html), a [JSON API](json-api.md)
  and an [HTTP API](web-api.md) to perform Walrus operations.
- Aggregators are services that allow download of blobs via HTTP requests.
- Publishers are services used to upload blobs to Walrus.
- A set of storage nodes store encoded stored blobs.

Aggregators, Publishers and other services use the client APIs to interact with Walrus. End-users
of services using walrus interact with the store via custom services, aggregators or publishers that
expose HTTP APIs to avoid the need to run locally a binary client.
