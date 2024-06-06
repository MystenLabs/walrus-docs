import base64

# Convert a numeric (u256) blob_id to a base64 encoded Blob ID
def num_to_blob_id(blob_id_num):
    extracted_bytes = []
    for i in range(32):
        extracted_bytes += [ blob_id_num & 0xff ]
        blob_id_num = blob_id_num >> 8
    assert blob_id_num == 0
    blob_id_bytes = bytes(extracted_bytes)
    encoded = base64.urlsafe_b64encode(blob_id_bytes)
    return encoded.decode("ascii").strip("=")

if __name__ == "__main__":
    blob_id_num = 46269954626831698189342469164469112511517843773769981308926739591706762839432
    blob_id_base64 = "iIWkkUTzPZx-d1E_A7LqUynnYFD-ztk39_tP8MLdS2Y"
    assert num_to_blob_id(blob_id_num) == blob_id_base64
