# Track Walrus storage related events on the Sui blockchain
#
# Prerequisites:
#
# - Configure Walrus
#   see: TODO(#12)
#
# - Update the paths PATH_TO_WALRUS_CONFIG below
#

import datetime

# Std lib imports
import requests
import re

from utils import num_to_blob_id

PATH_TO_WALRUS_CONFIG = "../CONFIG/config_dir/client_config.yaml"

system_object_id = re.findall(r"system_object:[ ]*(.*)", open(PATH_TO_WALRUS_CONFIG).read())[0]
print(f'System object ID: {system_object_id}')

# Query the Walrus system object on Sui
request = {
"jsonrpc": "2.0",
"id": 1,
"method": "sui_getObject",
"params": [
    system_object_id,
    {
    "showType": True,
    "showOwner": False,
    "showPreviousTransaction": False,
    "showDisplay": False,
    "showContent": False,
    "showBcs": False,
    "showStorageRebate": False
    }
]
}
response = requests.post("https://fullnode.testnet.sui.io:443", json=request)
assert response.status_code == 200

system_object_content = response.json()['result']['data']
walrus_type = re.findall("(0x[0-9a-f]+)::system", system_object_content["type"])[0]
print(f'Walrus type: {walrus_type}')

# Query events for the appropriate Walrus type
request = {
    "jsonrpc": "2.0",
    "id": 1,
    "method": "suix_queryEvents",
    "params": [
    # Query by module type
    {
        "MoveModule": {
        "package": walrus_type,
        "module": "blob"
        }
    },
    None,
    # Query the latest 100 events
    100,
    True
    ]
}
response = requests.post("https://fullnode.testnet.sui.io:443", json=request)
assert response.status_code == 200

events = response.json()['result']['data']
for event in events:
    # Parse the Walrus event
    tx_digest = event['id']['txDigest']
    event_type = event['type'][68+13:]
    parsed_event = event['parsedJson']
    blob_id = num_to_blob_id(int(parsed_event["blob_id"]))
    timestamp_ms = int(event["timestampMs"])
    time_date = datetime.datetime.fromtimestamp(timestamp_ms/1000.0)

    # For registered blobs get their size in bytes
    if event_type == "BlobRegistered":
        size = f"{parsed_event['size']}b"
    else:
        size = ""

    print(f'{time_date} {event_type:<15} {size:>10} {blob_id} Tx:{tx_digest:<48}')
