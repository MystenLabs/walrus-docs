// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module walrus::encoding;

use walrus::redstuff;

// Supported Encoding Types
// RedStuff with RaptorQ
const RED_STUFF_RAPTOR: u8 = 0;
// RedStuff with Reed-Solomon
const RS2: u8 = 1;

// Error codes
// Error types in `walrus-sui/types/move_errors.rs` are auto-generated from the Move error codes.
/// The encoding type is invalid.
const EInvalidEncodingType: u64 = 0;

/// Computes the encoded length of a blob given its unencoded length, encoding type
/// and number of shards `n_shards`.
public fun encoded_blob_length(unencoded_length: u64, encoding_type: u8, n_shards: u16): u64 {
    // Currently only supports the two RedStuff variants.
    assert!(encoding_type == RED_STUFF_RAPTOR || encoding_type == RS2, EInvalidEncodingType);
    redstuff::encoded_blob_length(unencoded_length, n_shards, encoding_type)
}
