# Example of uploading and downloading a file to / from the Walrus service
# Using the walrus client web API facilities.
#
# Prerequisites:
#
# - Run the Walrus client in daemon mode:
#   $ ../CONFIG/bin/walrus --config ../CONFIG/config_dir/client_config.yaml daemon -b 127.0.0.1:8899
#

# Std lib imports
import os
import time

# External requests HTTP library
import requests

ADDRESS = "127.0.0.1:8899"
EPOCHS = "5"


# Helper functions to upload a blob
def upload_blob(ADDRESS, EPOCHS, data):
    # Upload the data to the Walrus service  using a PUT request
    store_url = f"http://{ADDRESS}/v1/store?epochs={EPOCHS}"
    response = requests.put(store_url, data=data)

    # Assert the response status code
    assert response.status_code == 200
    blob_id = response.json()["newlyCreated"]["blobObject"]["blobId"]
    return blob_id


# Helper functions to download a blob
def download_blob(ADDRESS, blob_id):
    # Now read the same resource using the blob-id
    read_url = f"http://{ADDRESS}/v1/{blob_id}"
    response = requests.get(read_url)

    # Assert the response status code
    assert response.status_code == 200
    return response.content


# Upload a random 1MB string then download it, and check it matches
if __name__ == "__main__":
    # Generate a 1MB blob of random data
    random_data = os.urandom(1024 * 1024)

    # Upload the blob to the Walrus service
    start_time = time.time()
    blob_id = upload_blob(ADDRESS, EPOCHS, random_data)
    upload_time = time.time()

    # Now download the same blob using the blob-id
    data = download_blob(ADDRESS, blob_id)
    assert data == random_data
    download_time = time.time()

    # Print some information about the blob
    print(f"Blob ID: {blob_id}")
    print(f"Size {len(random_data)} bytes")
    print(f"Upload time: {upload_time - start_time:.2f}s")
    print(f"Download time: {download_time - upload_time:.2f}s")
