// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::encoding;

use walrus::redstuff;

// Supported Encoding Types
const RED_STUFF_ENCODING: u8 = 0;

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
const EInvalidEncoding: u64 = 0;

/// Computes the encoded length of a blob given its unencoded length, encoding type
/// and number of shards `n_shards`.
public fun encoded_blob_length(unencoded_length: u64, encoding_type: u8, n_shards: u16): u64 {
    // Currently only supports a single encoding type
    assert!(encoding_type == RED_STUFF_ENCODING, EInvalidEncoding);
    redstuff::encoded_blob_length(unencoded_length, n_shards)
}
