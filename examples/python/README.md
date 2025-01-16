# Walrus Python Examples

## Prerequisites

- Set up Sui and Walrus as described [here](https://docs.walrus.site/usage/setup.html).
- Optional: Set up a Python virtual environment:

  ```sh
  python -m venv .venv
  source .venv/bin/activate
  ```

- Install the dependencies:

  ```sh
  pip install -r requirements.txt
  ```

- Update the paths `PATH_TO_WALRUS` and `PATH_TO_WALRUS_CONFIG` and other constant in `utils.py`.

## Index of examples

- `hello_walrus_jsonapi.py` shows how to store and read blobs using the JSON API of the Walrus
  client.
- `hello_walrus_webapi.py` shows how to store and read blobs using the HTTP API of the Walrus
  client.
- `track_walrus_events.py` is a simple script to track all Walrus-related events on Sui.
