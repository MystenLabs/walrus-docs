# Example of querying the Walrus system object on Sui

# Std lib imports
import requests
import re

from utils import PATH_TO_WALRUS_CONFIG

system_object_id = re.findall(
    r"system_object:[ ]*(.*)", open(PATH_TO_WALRUS_CONFIG).read()
)[0]
print(f"System object ID: {system_object_id}")

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
            "showPreviousTransaction": True,
            "showDisplay": False,
            "showContent": True,
            "showBcs": False,
            "showStorageRebate": False,
        },
    ],
}
response = requests.post("https://fullnode.testnet.sui.io:443", json=request)
assert response.status_code == 200

system_object_content = response.json()["result"]["data"]["content"]["fields"]
committee = system_object_content["current_committee"]["fields"]["bls_committee"][
    "fields"
]

print(
    f'Current walrus epoch: {system_object_content["current_committee"]["fields"]["epoch"]}'
)
print(
    f'Number of members: {len(committee["members"])} Number of shards: {committee["n_shards"]}'
)
print(f'Price per unit size: {system_object_content["price_per_unit_size"]} MIST')
print(f'Total capacity size: {system_object_content["total_capacity_size"]} bytes')
print(f'Used capacity size: {system_object_content["used_capacity_size"]} bytes')
