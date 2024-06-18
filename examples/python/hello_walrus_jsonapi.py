# Example of uploading and downloading a file to / from the Walrus service
# Using the walrus client json input & output facilities.

# Std lib imports
import os
import subprocess
import json
import tempfile
import base64

import requests

from utils import num_to_blob_id, PATH_TO_WALRUS, PATH_TO_WALRUS_CONFIG, FULL_NODE_URL

try:
    # Create a 1MiB file of random data
    random_data = os.urandom(1024 * 1024)
    tmp = tempfile.NamedTemporaryFile(delete=False)
    tmp.write(random_data)
    tmp.close()

    # Part 1. Upload the file to the Walrus service
    store_json_command = f"""{{ "config" : "{PATH_TO_WALRUS_CONFIG}",
        "command" : {{ "store" :
        {{ "file" : "{tmp.name}", "epochs" : 2  }}}}
    }}"""
    result = subprocess.run(
        [PATH_TO_WALRUS, "json"],
        text=True,
        capture_output=True,
        input=store_json_command,
    )

    assert result.returncode == 0

    # Parse the response and display key information
    json_result_dict = json.loads(result.stdout.strip())
    if "newlyCreated" in json_result_dict:
        blob_id = json_result_dict["newlyCreated"]["blobObject"]["blobId"]
        sui_object_id = json_result_dict["newlyCreated"]["blobObject"]["id"]
    elif "alreadyCertified" in json_result_dict:
        blob_id = json_result_dict["alreadyCertified"]["blobObject"]["blobId"]
        sui_object_id = json_result_dict["alreadyCertified"]["blobObject"]["id"]
    else:
        raise ValueError("Unexpected response from Walrus")

    print(
        f"Upload Blob ID: {blob_id} Size {len(random_data)} bytes"
    )

    print(f"Certificate in Object ID: {sui_object_id}")

    # Part 2. Download the file from the Walrus service
    read_json_command = f"""{{ "config" : "{PATH_TO_WALRUS_CONFIG}",
        "command" : {{ "read" :
        {{ "blobId" : "{blob_id}" }}}}
    }}"""
    result = subprocess.run(
        [PATH_TO_WALRUS, "json"],
        text=True,
        capture_output=True,
        input=read_json_command,
    )

    assert result.returncode == 0

    # Parse the response and display key information
    json_result_dict = json.loads(result.stdout.strip())
    downloaded_data = base64.b64decode(json_result_dict["blob"])
    assert downloaded_data == random_data

    print(
        f"Download Blob ID: {json_result_dict['blobId']} Size {len(downloaded_data)} bytes"
    )

    # Part 3. Check the availability of the blob
    request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "sui_getObject",
        "params": [
            sui_object_id,
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
    response = requests.post(FULL_NODE_URL, json=request)
    object_content = response.json()["result"]["data"]["content"]
    print("Object content:")
    print(json.dumps(object_content, indent=4))

    # Check that the blob ID matches the one we uploaded
    blob_id_downloaded = int(object_content["fields"]["blob_id"])
    if num_to_blob_id(blob_id_downloaded) == blob_id:
        print("Blob ID matches certificate!")
    else:
        print("Blob ID does not match")

finally:
    os.unlink(tmp.name)
